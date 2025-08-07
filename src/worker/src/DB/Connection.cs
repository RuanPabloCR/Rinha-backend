using System;
using System.Text.Json;
using Model;
using StackExchange.Redis;
namespace DB
{
    public class Connection
    {
        private static readonly Lazy<ConnectionMultiplexer> lazyConnection =
            new Lazy<ConnectionMultiplexer>(() =>
            {
                string redisHost = Environment.GetEnvironmentVariable("REDIS_HOST") ?? "localhost:6379";
                return ConnectionMultiplexer.Connect(redisHost);
            });

        private static ConnectionMultiplexer ConnectionMultiplexer => lazyConnection.Value;

        private readonly IDatabase db;
        public Connection()
        {
            db = ConnectionMultiplexer.GetDatabase();
        }
        public async Task<Payment?> GetRightValueAsync(string key)
        {
            var redisValue = await db.ListRightPopAsync(key);
            if (redisValue.IsNull)
            {
                return null;
            }

            var options = new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true,
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase
            };

            return JsonSerializer.Deserialize<Payment>(redisValue.ToString(), options);
        }
        public async Task PushRightValueAsync(string key, Payment value)
        {
            var json = JsonSerializer.Serialize(value);
            await db.ListRightPushAsync(key, json);
        }

        public async Task AddLogAsync(string key, double score, string message)
        {
            await db.SortedSetAddAsync(key, message, score);
        }
    }
}