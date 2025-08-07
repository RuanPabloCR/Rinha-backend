namespace Model
{
    public class Payment
    {
        public Guid CorrelationId { get; set; }
        public decimal Amount { get; set; }
        public DateTime RequestedAt { get; set; }

        public Payment(Guid correlationId, decimal amount, DateTime requestedAt)
        {
            CorrelationId = correlationId;
            Amount = amount;
            RequestedAt = requestedAt;
        }

        public Payment()
        {
            CorrelationId = Guid.NewGuid();
            RequestedAt = DateTime.UtcNow;
        }
    }
}