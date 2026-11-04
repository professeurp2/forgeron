"""Tests du service reco3d.

Le runner de production refuse tant que Meshroom/TRELLIS ne sont pas branchés ;
ces tests injectent donc `FakeRunner`, explicitement factice, pour vérifier la
MÉCANIQUE du service (file, jalons, provenance, téléchargement) — pas la
qualité d'une reconstruction.

Lancer :  python -m pytest tool/reco3d -v
"""

import sys
import time
from pathlib import Path

RECO3D_DIR = Path(__file__).resolve().parent
if str(RECO3D_DIR) not in sys.path:
    sys.path.insert(0, str(RECO3D_DIR))

import pytest
from starlette.testclient import TestClient

import service
from models import JobMode, JobStage
from runners import EngineUnavailable, LocalEnginesRunner, RunnerResult


class FakeRunner:
    """Runner de TEST : écrit un STL minimal et rapporte ce qu'on lui dit."""

    def __init__(self, scale_detected=False, fail=None):
        self.scale_detected = scale_detected
        self.fail = fail

    def availability(self, mode):
        return True, "factice (test)"

    async def run(self, mode, photos_dir, out_dir, declared_scale, on_stage):
        if self.fail:
            raise EngineUnavailable(self.fail)
        for stage, pct in [(JobStage.SFM, 15), (JobStage.MVS, 45), (JobStage.MESHING, 75)]:
            await on_stage(stage, pct, stage.value)
        mesh = out_dir / "piece.stl"
        mesh.write_text("solid t\nendsolid t\n", encoding="utf-8")
        return RunnerResult(mesh_path=mesh, engine="fake", engine_version="0",
                            scale_detected=self.scale_detected)


@pytest.fixture
def make_client(tmp_path, monkeypatch):
    monkeypatch.setattr(service, "STORAGE_DIR", tmp_path)
    service.jobs_db.clear()

    def _make(runner):
        monkeypatch.setattr(service, "runner", runner)
        return TestClient(service.app)

    return _make


def _submit(client, **data):
    res = client.post("/jobs", data=data,
                      files={"photos": ("../../evil.jpg", b"img", "image/jpeg")})
    assert res.status_code == 202, res.text
    return res.json()["job_id"]


def _wait(client, job_id, max_retries=150, delay=0.04):
    for _ in range(max_retries):
        st = client.get(f"/jobs/{job_id}").json()
        if st["stage"] in ("done", "failed"):
            return st
        time.sleep(delay)
    pytest.fail(f"job {job_id} bloqué : {st}")


def test_health_reports_engines(make_client):
    with make_client(FakeRunner()) as c:
        data = c.get("/health").json()
    assert set(data["engines"]) == {"photo", "gen"}


def test_production_runner_never_fakes_a_result(make_client):
    runner = LocalEnginesRunner()
    ok, reason = runner.availability(JobMode.PHOTO)
    if not ok:
        with make_client(runner) as c:
            st = _wait(c, _submit(c, mode="photo"))
            assert st["stage"] == "failed"
            assert st["has_mesh"] is False and st["provenance"] is None
            assert c.get(f"/jobs/{st['job_id']}/result").status_code == 409
    else:
        # Quand le moteur est présent, il est opérationnel et ne fabrique pas de faux fichiers
        assert "Meshroom" in reason


def test_declared_scale_alone_stays_approximate(make_client):
    # L'utilisateur déclare une mire, le moteur ne la trouve pas.
    with make_client(FakeRunner(scale_detected=False)) as c:
        st = _wait(c, _submit(c, mode="photo", scale_type="aruco", scale_mm="50"))
    assert st["stage"] == "done"
    assert st["provenance"]["is_approximate"] is True
    assert st["provenance"]["has_scale_reference"] is False


def test_detected_scale_lifts_approximate(make_client):
    with make_client(FakeRunner(scale_detected=True)) as c:
        st = _wait(c, _submit(c, mode="photo", scale_type="aruco", scale_mm="50"))
    prov = st["provenance"]
    assert prov["is_approximate"] is False
    assert prov["scale_factor"] == 50.0


def test_generative_is_always_approximate(make_client):
    with make_client(FakeRunner(scale_detected=True)) as c:
        job_id = _submit(c, mode="gen")
        st = _wait(c, job_id)
        assert st["provenance"]["is_approximate"] is True
        res = c.get(f"/jobs/{job_id}/result?format=mesh")
        assert res.status_code == 200 and res.content.startswith(b"solid")
        # Pas de STEP produit -> 404, pas un fichier vide.
        assert c.get(f"/jobs/{job_id}/result?format=step").status_code == 404


def test_upload_name_cannot_escape_job_dir(make_client, tmp_path):
    with make_client(FakeRunner()) as c:
        job_id = _submit(c, mode="photo")
        _wait(c, job_id)
    assert not (tmp_path.parent / "evil.jpg").exists()
    assert (tmp_path / job_id / "photos" / "000.jpg").exists()


def test_invalid_inputs_rejected(make_client):
    with make_client(FakeRunner()) as c:
        files = {"photos": ("a.jpg", b"x", "image/jpeg")}
        assert c.post("/jobs", data={"mode": "x"}, files=files).status_code == 400
        assert c.post("/jobs", data={"scale_type": "aruco"}, files=files).status_code == 400
        assert c.get("/jobs/inconnu").status_code == 404


def test_machine_scan_bounds_rejected(make_client):
    with make_client(FakeRunner()) as c:
        # A hors course (> 90°)
        assert c.post("/scan", json={"poses": 8, "a_deg": 95.0}).status_code in (400, 422)
        # A hors course (< -88°)
        assert c.post("/scan", json={"poses": 8, "a_deg": -90.0}).status_code in (400, 422)
        # Nombre de poses invalide
        assert c.post("/scan", json={"poses": 0, "a_deg": 0.0}).status_code in (400, 422)
        assert c.post("/scan", json={"poses": 100, "a_deg": 0.0}).status_code in (400, 422)


def test_machine_scan_simulation_pipeline(make_client, tmp_path):
    with make_client(FakeRunner()) as c:
        res = c.post("/scan", json={"poses": 6, "a_deg": 15.0, "synthetic": True})
        assert res.status_code == 202, res.text
        data = res.json()
        job_id = data["job_id"]
        assert data["mode"] == "gen"

        st = _wait(c, job_id)
        assert st["stage"] == "done"
        assert st["has_mesh"] is True

        # Vérification des fichiers de capture
        job_dir = tmp_path / job_id
        assert (job_dir / "views.json").exists()
        photos = list((job_dir / "photos").glob("*.jpg"))
        assert len(photos) == 6

        # Vérification de l'honnêteté de la provenance
        prov = st["provenance"]
        assert prov["is_approximate"] is True
        notes = " ".join(prov["notes"])
        assert "Scan en machine (Jalon 5.0)" in notes
        assert "simulation, boucle ouverte" in notes


def test_machine_scan_unreachable_camera_fails_honestly(make_client):
    with make_client(FakeRunner()) as c:
        res = c.post(
            "/scan",
            json={
                "poses": 4,
                "a_deg": 0.0,
                "camera_url": "http://127.0.0.1:59999/capture",
                "synthetic": False,
            },
        )
        assert res.status_code == 202
        job_id = res.json()["job_id"]

        st = _wait(c, job_id)
        assert st["stage"] == "failed"
        assert "Échec capture" in (st["error"] or "")

