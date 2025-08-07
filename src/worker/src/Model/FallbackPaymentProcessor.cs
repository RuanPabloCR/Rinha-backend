namespace Model
{
    public static class FallbackPaymentProcessor
    {
        public static string FallbackPaymentHealthCheckUrl { get; set; } = "http://payment-processor-fallback:8080/payments/service-health";
        public static string PaymentServiceUrl { get; set; } = "http://payment-processor-fallback:8080/payments";
    }
}