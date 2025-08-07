using Services;
using DB;
using System.Text.Json;
using Model;
class Program
{
    static async Task Main(string[] args)
    {
        int workerCount = 26;
        var paymentService = new PaymentService();
        var tasks = new List<Task>();
        var defaultHealthCheckService = new HealthCheckService();
        var fallbackHealthCheckService = new HealthCheckService();
        defaultHealthCheckService.Start(DefaultPaymentProcessor.DefaultPaymentHealthCheckUrl);
        fallbackHealthCheckService.Start(FallbackPaymentProcessor.FallbackPaymentHealthCheckUrl);

        Console.WriteLine("Health check services started. Waiting for initialization...");


        await Task.Delay(2000);

        Console.WriteLine($"Starting {workerCount} workers...");

        for (int i = 0; i < workerCount; i++)
        {
            tasks.Add(Task.Run(async () =>
            {
                while (true)
                {
                    bool success = false;
                    try
                    {
                        // Tentar primeiro o default se estiver saudável
                        if (defaultHealthCheckService.CurrentHealthCheck != null && !defaultHealthCheckService.CurrentHealthCheck.Failing)
                        {
                            success = await paymentService.ProcessPaymentAsync(DefaultPaymentProcessor.PaymentServiceUrl);
                        }

                        if (!success && fallbackHealthCheckService.CurrentHealthCheck != null && !fallbackHealthCheckService.CurrentHealthCheck.Failing)
                        {
                            success = await paymentService.ProcessPaymentAsync(FallbackPaymentProcessor.PaymentServiceUrl, true);
                        }

                        if (!success)
                        {
                            //System.Diagnostics.Debug.WriteLine("No payment processor available or no payments to process.");
                            await Task.Delay(90);
                        }
                    }
                    catch (Exception)
                    {
                        //System.Diagnostics.Debug.WriteLine($"Error processing payment: {ex.Message}");
                        await Task.Delay(90);
                    }


                    await Task.Delay(90);
                }
            }));
        }

        await Task.WhenAll(tasks);
    }
}