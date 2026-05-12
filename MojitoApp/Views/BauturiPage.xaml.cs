using System.Windows;
using System.Windows.Controls;
using Microsoft.Data.SqlClient;
using MojitoApp.Helpers;
using MojitoApp.Models;

namespace MojitoApp.Views
{
    public partial class BauturiPage : Page
    {
        private ProdusDisplay? _produsSelectat = null;

        public BauturiPage()
        {
            InitializeComponent();
            IncarcaProduse();
        }

        private void IncarcaProduse()
        {
            listCeaiuri.ItemsSource = GetProduse(172, 186);
            listCafea.ItemsSource = GetProduse(176, 182);
            listSoft.ItemsSource = GetProduse(187, 200);
            listWhisky.ItemsSource = GetProduse(201, 225);
            listVodcaGin.ItemsSource = GetProduse(230, 241);
            listRomTequila.ItemsSource = GetProduse(226, 246);
            listConiac.ItemsSource = GetProduse(247, 257);
            listBere.ItemsSource = GetProduse(258, 263);
            listVin.ItemsSource = GetProduse(264, 312);
        }

        private List<ProdusDisplay> GetProduse(int idStart, int idEnd)
        {
            var lista = new List<ProdusDisplay>();
            using var conn = DatabaseHelper.GetConnection();
            conn.Open();
            string query = @"SELECT id, nume, gramaj, pret
                            FROM Produse
                            WHERE id BETWEEN @s AND @e
                            ORDER BY id";
            using var cmd = new SqlCommand(query, conn);
            cmd.Parameters.AddWithValue("@s", idStart);
            cmd.Parameters.AddWithValue("@e", idEnd);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                lista.Add(new ProdusDisplay
                {
                    Id = reader.GetInt32(0),
                    Nume = reader.GetString(1),
                    Gramaj = reader.IsDBNull(2) ? "" : reader.GetString(2),
                    Pret = reader.GetDecimal(3),
                    Ingrediente = ""
                });
            }
            return lista;
        }

        private void list_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (sender is ListView lv && lv.SelectedItem is ProdusDisplay p)
            {
                _produsSelectat = p;
                ActualizeazaTotal();
            }
        }

        private void btnPlus_Click(object sender, RoutedEventArgs e)
        {
            if (int.TryParse(txtCantitate.Text, out int val) && val < 99)
            {
                txtCantitate.Text = (val + 1).ToString();
                ActualizeazaTotal();
            }
        }

        private void btnMinus_Click(object sender, RoutedEventArgs e)
        {
            if (int.TryParse(txtCantitate.Text, out int val) && val > 1)
            {
                txtCantitate.Text = (val - 1).ToString();
                ActualizeazaTotal();
            }
        }

        private void ActualizeazaTotal()
        {
            if (_produsSelectat != null &&
                int.TryParse(txtCantitate.Text, out int cant))
                txtTotal.Text = $"Total: {_produsSelectat.Pret * cant} MDL";
        }

        private void btnAdaugaInCos_Click(object sender, RoutedEventArgs e)
        {
            if (_produsSelectat == null)
            {
                MessageBox.Show("Selectați un produs!", "Atenție",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            if (!int.TryParse(txtCantitate.Text, out int cantitate) || cantitate < 1)
            {
                MessageBox.Show("Cantitate invalidă!", "Atenție",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            CosComenzi.AdaugaProdus(new CosItem
            {
                IdProdus = _produsSelectat.Id,
                Nume = _produsSelectat.Nume,
                Pret = _produsSelectat.Pret,
                Cantitate = cantitate,
                TipScadere = _produsSelectat.TipScadere
            });

            MessageBox.Show($"✅ {_produsSelectat.Nume} x{cantitate} adăugat în coș!",
                "Adăugat", MessageBoxButton.OK, MessageBoxImage.Information);

            txtCantitate.Text = "1";
            txtTotal.Text = "Total: 0 MDL";
            _produsSelectat = null;
        }
    }
}