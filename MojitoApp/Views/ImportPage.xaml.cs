using System.Windows;
using System.Windows.Controls;
using Microsoft.Data.SqlClient;
using MojitoApp.Helpers;
using MojitoApp.Services;

namespace MojitoApp.Views
{
    public class ImportItem
    {
        public int IdProdus { get; set; }
        public string Nume { get; set; } = "";
        public int Cantitate { get; set; }
        public decimal Pret { get; set; }
        public decimal Subtotal => Pret * Cantitate;
        public string Status { get; set; } = "";
        public string StatusColor => Status == "✓ Găsit" ? "#2ECC71" : "#E74C3C";
    }

    public partial class ImportPage : Page
    {
        private readonly VanzareService _vanzareService = new();
        private List<ImportItem> _items = new();

        public ImportPage()
        {
            InitializeComponent();
        }

        private void btnProceseaza_Click(object sender, RoutedEventArgs e)
        {
            _items = new List<ImportItem>();
            string input = txtInput.Text.Trim();

            if (string.IsNullOrWhiteSpace(input))
            {
                MessageBox.Show("Introduceți lista de produse!", "Atenție",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            string[] linii = input.Split('\n',
                StringSplitOptions.RemoveEmptyEntries |
                StringSplitOptions.TrimEntries);

            foreach (string linie in linii)
            {
                if (string.IsNullOrWhiteSpace(linie)) continue;

                // Extragem cantitatea (ultimul cuvant daca e numar)
                string[] parti = linie.Trim().Split(' ');
                int cantitate = 1;
                string numeProdus = linie.Trim();

                if (parti.Length > 1 && int.TryParse(parti[^1], out int cant))
                {
                    cantitate = cant;
                    numeProdus = string.Join(" ", parti[..^1]).Trim();
                }

                // Cautam produsul in BD (cautare fuzzy)
                var produs = CautaProdus(numeProdus);

                if (produs != null)
                {
                    _items.Add(new ImportItem
                    {
                        IdProdus = produs.Value.id,
                        Nume = produs.Value.nume,
                        Cantitate = cantitate,
                        Pret = produs.Value.pret,
                        Status = "✓ Găsit"
                    });
                }
                else
                {
                    _items.Add(new ImportItem
                    {
                        IdProdus = -1,
                        Nume = numeProdus,
                        Cantitate = cantitate,
                        Pret = 0,
                        Status = "✗ Negăsit"
                    });
                }
            }

            listPreview.ItemsSource = _items;
            decimal total = _items.Where(i => i.IdProdus > 0).Sum(i => i.Subtotal);
            txtTotal.Text = $"{total:F2} MDL";
        }

        private (int id, string nume, decimal pret)? CautaProdus(string numeCautat)
        {
            try
            {
                using var conn = DatabaseHelper.GetConnection();
                conn.Open();

                // Cautare exacta mai intai
                string query = @"SELECT TOP 1 id, nume, pret FROM Produse
                                WHERE LOWER(nume) = LOWER(@n)";
                using var cmd = new SqlCommand(query, conn);
                cmd.Parameters.AddWithValue("@n", numeCautat);
                using var reader = cmd.ExecuteReader();

                if (reader.Read())
                    return (reader.GetInt32(0), reader.GetString(1), reader.GetDecimal(2));

                reader.Close();

                // Cautare partiala
                string query2 = @"SELECT TOP 1 id, nume, pret FROM Produse
                                 WHERE LOWER(nume) LIKE LOWER(@n)
                                 ORDER BY LEN(nume) ASC";
                using var cmd2 = new SqlCommand(query2, conn);
                cmd2.Parameters.AddWithValue("@n", $"%{numeCautat}%");
                using var reader2 = cmd2.ExecuteReader();

                if (reader2.Read())
                    return (reader2.GetInt32(0), reader2.GetString(1), reader2.GetDecimal(2));

                return null;
            }
            catch { return null; }
        }

        private void btnConfirma_Click(object sender, RoutedEventArgs e)
        {
            var produsGasite = _items.Where(i => i.IdProdus > 0).ToList();

            if (produsGasite.Count == 0)
            {
                MessageBox.Show("Niciun produs valid găsit!", "Atenție",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            int negasite = _items.Count(i => i.IdProdus < 0);
            string mesaj = $"Confirmați comanda?\n\n" +
                           $"Produse găsite: {produsGasite.Count}\n" +
                           $"Produse negăsite: {negasite}\n" +
                           $"Total: {produsGasite.Sum(i => i.Subtotal):F2} MDL";

            var confirmare = MessageBox.Show(mesaj, "Confirmare",
                MessageBoxButton.YesNo, MessageBoxImage.Question);

            if (confirmare == MessageBoxResult.Yes)
            {
                decimal total = produsGasite.Sum(i => i.Subtotal);
                int idVanzare = _vanzareService.CreeazaVanzare(1, total);

                foreach (var item in produsGasite)
                {
                    _vanzareService.AdaugaDetaliu(idVanzare, item.IdProdus,
                        item.Cantitate, item.Pret);
                }

                _vanzareService.ScadeStoc(idVanzare);

                MessageBox.Show(
                    $"✅ Comandă procesată!\n{produsGasite.Count} produse\nTotal: {total:F2} MDL",
                    "Succes", MessageBoxButton.OK, MessageBoxImage.Information);

                txtInput.Clear();
                _items.Clear();
                listPreview.ItemsSource = null;
                txtTotal.Text = "0.00 MDL";
            }
        }

        private void btnGoleste_Click(object sender, RoutedEventArgs e)
        {
            txtInput.Clear();
            _items.Clear();
            listPreview.ItemsSource = null;
            txtTotal.Text = "0.00 MDL";
        }
    }
}