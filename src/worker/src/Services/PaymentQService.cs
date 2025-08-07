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
                Timeout = TimeSpan.FromSeconds(5) // Timeout mais generoso: 5 segundos
            };
        }

        public async Task<bool> ProcessPaymentAsync(string url, bool isRetry = false)
        {
            try
            {
                Payment? PaymentToProcess = await _connection.GetRightValueAsync("payments_queue");
                if (PaymentToProcess == null)
                {
                    return false; // Não há pagamento para processar
                }
                else
                {
                    // Debug: mostrar dados do pagamento antes de processar
                    //Console.WriteLine($"🔍 DEBUG - Payment to process:");
                    //Console.WriteLine($"🔍 CorrelationId: {PaymentToProcess.CorrelationId}");
                    //Console.WriteLine($"🔍 Amount: {PaymentToProcess.Amount}");
                    //Console.WriteLine($"🔍 RequestedAt: {PaymentToProcess.RequestedAt}");
                    //Console.WriteLine($"🔍 Trying URL: {url}");

                    var response = await _httpClient.PostAsJsonAsync(url, PaymentToProcess);
                    if (response.IsSuccessStatusCode)
                    {
                        //Console.WriteLine("Payment processed successfully.");

                        // Determinar o source baseado na URL
                        string source = url.Contains("payment-processor-default") ? "default" : "fallback";

                        // Criar objeto JSON simplificado do pagamento para o summary
                        var processedPayment = new
                        {
                            correlationId = PaymentToProcess.CorrelationId,
                            amount = PaymentToProcess.Amount,
                            requestedAt = PaymentToProcess.RequestedAt,
                            source = source
                        };

                        // Salvar o pagamento processado como JSON
                        // Usar o timestamp do requestedAt em vez do tempo atual
                        double timestamp = ((DateTimeOffset)PaymentToProcess.RequestedAt).ToUnixTimeMilliseconds();
                        string paymentJson = System.Text.Json.JsonSerializer.Serialize(processedPayment);
                        //Console.WriteLine($"🔍 DEBUG - JSON to save: {paymentJson}");
                        //Console.WriteLine($"🔍 DEBUG - Using timestamp from RequestedAt: {timestamp}");
                        await _connection.AddLogAsync("payments:logs", timestamp, paymentJson);
                        return true; // Sucesso
                    }
                    else
                    {
                        //Console.WriteLine($"Failed to process payment. Status: {response.StatusCode}");

                        // Se não é retry e falhou, devolver o pagamento para a fila
                        if (!isRetry)
                        {
                            await _connection.PushRightValueAsync("payments_queue", PaymentToProcess);
                        }
                        return false; // Falha
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