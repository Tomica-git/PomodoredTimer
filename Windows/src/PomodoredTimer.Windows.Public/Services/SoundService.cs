using System.IO;
using System.Media;

namespace PomodoredTimer.Windows.Public.Services;

public sealed class SoundService : IDisposable
{
    private readonly MemoryStream tickStream = CreateWave(1_700, 28, 0.22);
    private readonly MemoryStream tockStream = CreateWave(720, 55, 0.30);
    private readonly SoundPlayer tickPlayer;
    private readonly SoundPlayer tockPlayer;

    public SoundService()
    {
        tickPlayer = new SoundPlayer(tickStream);
        tockPlayer = new SoundPlayer(tockStream);
        tickPlayer.Load();
        tockPlayer.Load();
    }

    public void PlayTick() => tickPlayer.Play();

    public void PlayTock() => tockPlayer.Play();

    public void PlayCompletion() => SystemSounds.Asterisk.Play();

    public void Dispose()
    {
        tickPlayer.Dispose();
        tockPlayer.Dispose();
        tickStream.Dispose();
        tockStream.Dispose();
    }

    private static MemoryStream CreateWave(double frequency, int durationMilliseconds, double amplitude)
    {
        const int sampleRate = 22_050;
        const short channels = 1;
        const short bitsPerSample = 16;
        var sampleCount = sampleRate * durationMilliseconds / 1_000;
        var dataLength = sampleCount * channels * bitsPerSample / 8;
        var stream = new MemoryStream(44 + dataLength);
        using (var writer = new BinaryWriter(stream, System.Text.Encoding.UTF8, leaveOpen: true))
        {
            writer.Write("RIFF"u8.ToArray());
            writer.Write(36 + dataLength);
            writer.Write("WAVE"u8.ToArray());
            writer.Write("fmt "u8.ToArray());
            writer.Write(16);
            writer.Write((short)1);
            writer.Write(channels);
            writer.Write(sampleRate);
            writer.Write(sampleRate * channels * bitsPerSample / 8);
            writer.Write((short)(channels * bitsPerSample / 8));
            writer.Write(bitsPerSample);
            writer.Write("data"u8.ToArray());
            writer.Write(dataLength);

            for (var index = 0; index < sampleCount; index++)
            {
                var progress = (double)index / sampleCount;
                var envelope = Math.Pow(1 - progress, 3);
                var sample = Math.Sin(2 * Math.PI * frequency * index / sampleRate)
                    * envelope
                    * amplitude;
                writer.Write((short)(sample * short.MaxValue));
            }
        }

        stream.Position = 0;
        return stream;
    }
}
