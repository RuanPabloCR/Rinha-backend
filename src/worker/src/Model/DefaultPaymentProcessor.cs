namespace Model
{
    public static class DefaultPaymentProcessor
    {
        public static string DefaultPaymentHealthCheckUrl { get; set; } = "http://payment-processor-default:8080/payments/service-health";
        public static string PaymentServiceUrl { get; set; } = "http://payment-processor-default:8080/payments";
    }
}