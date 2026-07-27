using System.Text.Json;
using System.Text.Json.Serialization;
using PomodoredTimer.Domain;

namespace PomodoredTimer.Application;

public readonly record struct StateLoadResult(
    TimerState State,
    bool RecoveredFromCorruption,
    string? QuarantinePath);

public sealed class PublicStateStore
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true,
        Converters = { new JsonStringEnumConverter(JsonNamingPolicy.CamelCase) },
    };

    public PublicStateStore(string? storageDirectory = null)
    {
        StorageDirectory = storageDirectory ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "PomodoredTimer",
            "Public");
        StatePath = Path.Combine(StorageDirectory, "state.v1.json");
        BackupPath = Path.Combine(StorageDirectory, "state.v1.bak");
    }

    public string StorageDirectory { get; }

    public string StatePath { get; }

    public string BackupPath { get; }

    public StateLoadResult Load()
    {
        if (!File.Exists(StatePath))
        {
            return new StateLoadResult(TimerState.CreateDefault(), false, null);
        }

        try
        {
            var json = File.ReadAllText(StatePath);
            var state = JsonSerializer.Deserialize<TimerState>(json, JsonOptions)
                ?? throw new InvalidDataException("The public state document is empty.");
            if (!state.IsValid)
            {
                throw new InvalidDataException("The public state identity or schema is invalid.");
            }

            return new StateLoadResult(state, false, null);
        }
        catch (Exception exception) when (
            exception is JsonException or IOException or InvalidDataException or UnauthorizedAccessException)
        {
            Directory.CreateDirectory(StorageDirectory);
            var quarantinePath = Path.Combine(
                StorageDirectory,
                $"state.corrupt.{DateTimeOffset.UtcNow:yyyyMMddHHmmssfff}.json");
            File.Move(StatePath, quarantinePath, overwrite: false);
            return new StateLoadResult(TimerState.CreateDefault(), true, quarantinePath);
        }
    }

    public void Save(TimerState state)
    {
        state.SchemaVersion = TimerState.CurrentSchemaVersion;
        state.Platform = "windows";
        state.Edition = "public";
        if (!state.IsValid)
        {
            throw new InvalidOperationException("Refusing to persist invalid public timer state.");
        }

        Directory.CreateDirectory(StorageDirectory);
        var temporaryPath = Path.Combine(StorageDirectory, $"state.{Guid.NewGuid():N}.tmp");
        try
        {
            var bytes = JsonSerializer.SerializeToUtf8Bytes(state, JsonOptions);
            using (var stream = new FileStream(
                temporaryPath,
                FileMode.CreateNew,
                FileAccess.Write,
                FileShare.None,
                bufferSize: 16_384,
                FileOptions.WriteThrough))
            {
                stream.Write(bytes);
                stream.Flush(flushToDisk: true);
            }

            if (File.Exists(StatePath))
            {
                try
                {
                    File.Replace(temporaryPath, StatePath, BackupPath, ignoreMetadataErrors: true);
                }
                catch (PlatformNotSupportedException)
                {
                    File.Copy(StatePath, BackupPath, overwrite: true);
                    File.Move(temporaryPath, StatePath, overwrite: true);
                }
            }
            else
            {
                File.Move(temporaryPath, StatePath);
            }
        }
        finally
        {
            if (File.Exists(temporaryPath))
            {
                File.Delete(temporaryPath);
            }
        }
    }
}
