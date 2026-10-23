import io, re, time, pandas as pd, jiwer, warnings, os
warnings.filterwarnings('ignore')
import nemo.collections.asr as nemo_asr
df = pd.read_parquet('nyana.parquet')
os.makedirs('wav', exist_ok=True)
paths = []
for i, r in df.iterrows():
    p = f'wav/{i:02d}.wav'; import soundfile as sf, librosa
    y, sr = sf.read(io.BytesIO(r['audio']['bytes']))
    if y.ndim > 1: y = y.mean(axis=1)
    if sr != 16000: y = librosa.resample(y, orig_sr=sr, target_sr=16000)
    sf.write(p, y, 16000); paths.append(p)
m = nemo_asr.models.ASRModel.restore_from('quartznet.nemo', map_location='cpu')
t = time.time()
out = m.transcribe(paths, batch_size=8)
out = [o.text if hasattr(o, 'text') else o for o in (out[0] if isinstance(out, tuple) else out)]
dt = time.time() - t
norm = lambda s: re.sub(r"[^\w\s']", ' ', s.lower()).split()
ref = [' '.join(norm(x)) for x in df['reference']]
hyp = [' '.join(norm(x)) for x in out]
stored = [' '.join(norm(x)) for x in df['RobotsMali/stt-bm-quartznet15x5-v2']]
print('durée audio %.0fs, calcul %.1fs (CPU)' % (df['duration'].sum(), dt))
print('WER local  : %.1f %%' % (100 * jiwer.wer(ref, hyp)))
print('WER publié : %.1f %%' % (100 * jiwer.wer(ref, stored)))
print('CER local  : %.1f %%' % (100 * jiwer.cer(ref, hyp)))
pd.DataFrame({'ref': ref, 'hyp': hyp}).to_csv('resultats.csv', index=False)
for a, b in list(zip(ref, hyp))[:6]: print(' REF', a, '\n HYP', b)
