import fs from "node:fs";

const outputDirectory = process.argv[2];
if (!outputDirectory) {
  throw new Error("Usage: node make-sounds.mjs <output-directory>");
}
fs.mkdirSync(outputDirectory, { recursive: true });

const sampleRate = 44_100;
const needleSoundGain = 3;

function writeWav(name, duration, sampleAt) {
  const sampleCount = Math.ceil(sampleRate * duration);
  const dataSize = sampleCount * 2;
  const buffer = Buffer.alloc(44 + dataSize);
  buffer.write("RIFF", 0);
  buffer.writeUInt32LE(36 + dataSize, 4);
  buffer.write("WAVEfmt ", 8);
  buffer.writeUInt32LE(16, 16);
  buffer.writeUInt16LE(1, 20);
  buffer.writeUInt16LE(1, 22);
  buffer.writeUInt32LE(sampleRate, 24);
  buffer.writeUInt32LE(sampleRate * 2, 28);
  buffer.writeUInt16LE(2, 32);
  buffer.writeUInt16LE(16, 34);
  buffer.write("data", 36);
  buffer.writeUInt32LE(dataSize, 40);

  for (let index = 0; index < sampleCount; index += 1) {
    const time = index / sampleRate;
    const value = Math.max(-1, Math.min(1, sampleAt(time, duration) * needleSoundGain));
    buffer.writeInt16LE(Math.round(value * 32_767), 44 + index * 2);
  }
  fs.writeFileSync(`${outputDirectory}/${name}.wav`, buffer);
}

function deterministicNoise(index) {
  const value = Math.sin(index * 12.9898) * 43_758.5453;
  return (value - Math.floor(value)) * 2 - 1;
}

writeWav("tick", 0.028, (time, duration) => {
  const envelope = Math.exp(-time * 145) * Math.sin(Math.PI * time / duration);
  const tone = Math.sin(2 * Math.PI * 2_450 * time);
  const noise = deterministicNoise(Math.floor(time * sampleRate));
  return envelope * (tone * 0.68 + noise * 0.18);
});

writeWav("tock", 0.075, (time, duration) => {
  const envelope = Math.exp(-time * 52) * Math.sin(Math.PI * time / duration);
  const body = Math.sin(2 * Math.PI * 420 * time);
  const wood = Math.sin(2 * Math.PI * 880 * time) * 0.25;
  return envelope * (body * 0.72 + wood);
});
