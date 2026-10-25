"""Tests de l'infra de capture (doc §12). Tout tourne SANS MATÉRIEL :
SyntheticCamera + SimController. On vérifie la MÉCANIQUE (plan, étiquetage,
boucle ouverte, garde de course A), pas la qualité d'une reconstruction.

Lancer :  python -m pytest tool/reco3d/test_capture.py -v
"""

import sys
from pathlib import Path

RECO3D_DIR = Path(__file__).resolve().parent
if str(RECO3D_DIR) not in sys.path:
    sys.path.insert(0, str(RECO3D_DIR))

import pytest

from capture import (
    A_MAX_DEG,
    CapturePlan,
    ControllerError,
    Pose,
    SimController,
    SyntheticCamera,
    pose_in_course,
    run_capture,
)


def test_orbit_plan_has_n_poses():
    plan = CapturePlan.orbit_c(n=8, a_deg=0.0)
    assert len(plan.poses) == 8
    assert plan.poses[0] == Pose(0.0, 0.0)
    assert plan.poses[-1].c_deg == pytest.approx(315.0)


def test_open_loop_reports_commanded_angle():
    ctrl = SimController()
    ctrl.move_to(-30.0, 120.0)
    assert ctrl.position() == (-30.0, 120.0)


def test_run_capture_tags_every_view(tmp_path):
    plan = CapturePlan.orbit_c(n=6, a_deg=0.0)
    cams = [SyntheticCamera(id="cam0"), SyntheticCamera(id="cam1")]
    doc = run_capture(plan, cams, SimController(), tmp_path, simulation=True)

    # 6 poses x 2 caméras = 12 vues, chacune un fichier réel.
    assert doc["view_count"] == 12
    assert doc["open_loop"] is True
    files = list((tmp_path / "photos").glob("*.jpg"))
    assert len(files) == 12
    for v in doc["views"]:
        assert (tmp_path / v["file"]).exists()
        # Boucle ouverte : angle rapporté == angle commandé.
        assert v["a_deg"] == v["commanded_a_deg"]
        assert v["c_deg"] == v["commanded_c_deg"]
    assert (tmp_path / "views.json").exists()


def test_pose_out_of_a_course_is_refused(tmp_path):
    plan = CapturePlan([Pose(A_MAX_DEG + 10.0, 0.0)])  # A hors course
    with pytest.raises(ControllerError):
        run_capture(plan, [SyntheticCamera(id="cam0")], SimController(), tmp_path, simulation=True)


def test_pose_in_course_bounds():
    assert pose_in_course(Pose(0.0, 180.0))
    assert not pose_in_course(Pose(-120.0, 0.0))
