namespace Model
{
    public class HealthCheck
    {
        public bool Failing { get; set; }
        // Tempo minimo que indica o minimo de espera pra processar um pagamento
        public int? MinResponseTime { get; set; }

        public HealthCheck()
        {
            Failing = false;
            MinResponseTime = null;
        }
        public HealthCheck(bool failing, int? minResponseTime)
        {
            Failing = failing;
            MinResponseTime = minResponseTime;
        }
    }
}