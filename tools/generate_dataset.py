"""
Génère un mini-dataset audio des formules à partir de synthèse vocale.

Prérequis:
  pip install gTTS pydub
  Téléchargez ffmpeg et assurez-vous que ffmpeg est dans le PATH.

Usage:
  python tools/generate_dataset.py
Les fichiers seront créés dans dataset/generated/<sort>/...
"""

from pathlib import Path
from gtts import gTTS
from pydub import AudioSegment
from pydub.generators import WhiteNoise

SPELLS = [
    "Expelliarmus",
    "Lumos",
    "Nox",
    "Wingardium Leviosa",
    "Expecto Patronum",
    "Accio",
    "Alohomora",
    "Protego",
    "Stupefy",
    "Obliviate",
]

OUT = Path("dataset/generated")
OUT.mkdir(parents=True, exist_ok=True)

def synth(spell: str, idx: int, rate: float = 1.0, noise_db: float = -30.0):
    text = spell
    tts = gTTS(text=text, lang="la")  # latin prononciation proche
    tmp = OUT / f"tmp_{spell}_{idx}.mp3"
    tts.save(tmp.as_posix())
    base = AudioSegment.from_file(tmp.as_posix())
    base = base.speedup(playback_speed=rate)
    noise = WhiteNoise().to_audio_segment(duration=len(base)).apply_gain(noise_db)
    mixed = base.overlay(noise)
    dest_dir = OUT / spell.replace(" ", "_")
    dest_dir.mkdir(parents=True, exist_ok=True)
    out = dest_dir / f"sample_{idx}_r{rate}_n{int(abs(noise_db))}.wav"
    mixed.export(out.as_posix(), format="wav")
    tmp.unlink(missing_ok=True)

def main():
    for s in SPELLS:
        for i in range(3):
            synth(s, i, rate=1.0 + i * 0.1, noise_db=-35 + 5 * i)
    print(f"Dataset généré dans: {OUT.resolve()}")

if __name__ == "__main__":
    main()