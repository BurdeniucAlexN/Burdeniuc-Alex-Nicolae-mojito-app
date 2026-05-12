namespace MojitoApp.Models
{
    public class CosItem
    {
        public int IdProdus { get; set; }
        public string Nume { get; set; } = "";
        public decimal Pret { get; set; }
        public int Cantitate { get; set; }
        public string TipScadere { get; set; } = "";
        public decimal Subtotal => Pret * Cantitate;
    }
}