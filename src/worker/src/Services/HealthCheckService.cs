using System.Text.Json;
using Model;

namespace Services
{
    public class HealthCheckService
    {
        private readonly HttpClient _httpClient;
        private CancellationTokenSource? _cancellationTokenSource;
        private volatile HealthCheck _currentHealthCheck;
        public HealthCheck CurrentHealthCheck => _currentHealthCheck;
        public HealthCheckService()
        {
            _httpClient = new HttpClient();
            _currentHealthCheck = new HealthCheck(); // Inicializar com estado padrão
        }
        public void Stop()
        {
            _cancellationTokenSource?.Cancel();
        }
        public void Start(string url)
        {
            _cancellationTokenSource = new CancellationTokenSource();
            var token = _cancellationTokenSource.Token;

            Task.Run(async () =>
            {
                while (!token.IsCancellationRequested)
                {
                    try
                    {
                        var response = await _httpClient.GetAsync(url, token);
                        if (response.IsSuccessStatusCode)
                        {
                            HealthCheck updatedHealthCheck = JsonSerializer.Deserialize<HealthCheck>(
                                await response.Content.ReadAsStringAsync(token)
                            ) ?? new HealthCheck();
                            System.Diagnostics.Debug.WriteLine($"Health check successful: {JsonSerializer.Serialize(updatedHealthCheck)}");
                            _currentHealthCheck = updatedHealthCheck;
                        }
                        else
                        {
                            if (response.StatusCode == System.Net.HttpStatusCode.TooManyRequests)
                            {
                                System.Diagnostics.Debug.WriteLine("Health check rate limited.");
                            }
                            // Marcar como falhando quando a resposta não é success
                            _currentHealthCheck = new HealthCheck(true, null);
                            System.Diagnostics.Debug.WriteLine($"Health check failed with status: {response.StatusCode}");
                        }
                    }
                    catch (Exception ex)
                    {
                        System.Diagnostics.Debug.WriteLine($"Health check failed: {ex.Message}");
                        // Marcar como falhando quando há exceção
                        _currentHealthCheck = new HealthCheck(true, null);
                    }

                    await Task.Delay(5000, token);
                }
            }, token);
        }

    }
}