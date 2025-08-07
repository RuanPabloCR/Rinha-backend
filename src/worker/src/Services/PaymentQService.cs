using System.Net.Http.Json;
using DB;
using Model;

namespace Services
{
    public class PaymentService
    {
        private readonly Connection _connection;
        private readonly HttpClient _httpClient;
        public PaymentService()
        {
            _connection = new Connection();
            _httpClient = new HttpClient
            {
                Timeout = TimeSpan.FromSeconds(5)
            };
        }

        public async Task<bool> ProcessPaymentAsync(string url, bool isRetry = false)
        {
            try
            {
                Payment? PaymentToProcess = await _connection.GetRightValueAsync("payments_queue");
                if (PaymentToProcess == null)
                {
                    return false;
                }
                else
                {

                    var response = await _httpClient.PostAsJsonAsync(url, PaymentToProcess);
                    if (response.IsSuccessStatusCode)
                    {
                        string source = url.Contains("payment-processor-default") ? "default" : "fallback";

                        var processedPayment = new
                        {
                            correlationId = PaymentToProcess.CorrelationId,
                            amount = PaymentToProcess.Amount,
                            requestedAt = PaymentToProcess.RequestedAt,
                            source = source
                        };

                        double timestamp = ((DateTimeOffset)PaymentToProcess.RequestedAt).ToUnixTimeMilliseconds();
                        string paymentJson = System.Text.Json.JsonSerializer.Serialize(processedPayment);
                        await _connection.AddLogAsync("payments:logs", timestamp, paymentJson);
                        return true; // Sucesso
                    }
                    else
                    {
                        if (!isRetry)
                        {
                            await _connection.PushRightValueAsync("payments_queue", PaymentToProcess);
                        }
                        return false;
                    }
                }
            }
            catch (Exception)
            {
                //Console.WriteLine($"An error occurred while processing the payment: {ex.Message}");
                return false; // Falha
            }
        }
    }
}