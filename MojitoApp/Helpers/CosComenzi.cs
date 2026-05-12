using MojitoApp.Models;

namespace MojitoApp.Helpers
{
    public static class CosComenzi
    {
        public static List<CosItem> Items { get; private set; } = new();
        public static decimal Total => Items.Sum(i => i.Subtotal);

        public static event Action? CosActualizat;

        public static void AdaugaProdus(CosItem item)
        {
            var existent = Items.FirstOrDefault(i => i.IdProdus == item.IdProdus);
            if (existent != null)
                existent.Cantitate += item.Cantitate;
            else
                Items.Add(item);

            CosActualizat?.Invoke();
        }

        public static void StergeItem(int idProdus)
        {
            var item = Items.FirstOrDefault(i => i.IdProdus == idProdus);
            if (item != null)
            {
                Items.Remove(item);
                CosActualizat?.Invoke();
            }
        }

        public static void Goleste()
        {
            Items.Clear();
            CosActualizat?.Invoke();
        }
    }
}