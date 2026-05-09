using System.Windows;
using System.Windows.Controls;
using Microsoft.Data.SqlClient;
using MojitoApp.Helpers;
using MojitoApp.Services;

namespace MojitoApp.Views
{
    public partial class BarPage : Page
    {
        private readonly VanzareService _vanzareService = new();
        private ProdusDisplay? _produsSelectat = null;

        public BarPage()
        {
            InitializeComponent();
            IncarcaProduse();
        }

        private void IncarcaProduse()
        {
            listLimonade.ItemsSource = GetProduse(127, 132);
            listMatcha.ItemsSource = GetProduse(133, 136);
            listPlacebo.ItemsSource = GetProduse(137, 140);
            listAperive.ItemsSource = GetProduse(141, 144);
            listCampari.ItemsSource = GetProduse(145, 148);
            listSour.ItemsSource = GetProduse(149, 157);
            listLong.ItemsSource = GetProduse(158, 168);
            listStrong.ItemsSource = GetProduse(169, 171);
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
            {
                txtTotal.Text = $"Total: {_produsSelectat.Pret * cant} MDL";
            }
        }

        private void btnTasteaza_Click(object sender, RoutedEventArgs e)
        {
            if (_produsSelectat == null)
            {
                MessageBox.Show("Selectați un cocktail!", "Atenție",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            if (!int.TryParse(txtCantitate.Text, out int cantitate) || cantitate < 1)
            {
                MessageBox.Show("Cantitate invalidă!", "Atenție",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            decimal total = _produsSelectat.Pret * cantitate;

            var rezultat = MessageBox.Show(
                $"Tastați: {_produsSelectat.Nume}\nCantitate: {cantitate}\nTotal: {total} MDL",
                "Confirmare", MessageBoxButton.YesNo,
                MessageBoxImage.Question);

            if (rezultat == MessageBoxResult.Yes)
            {
                int idVanzare = _vanzareService.CreeazaVanzare(1, total);
                _vanzareService.AdaugaDetaliu(idVanzare, _produsSelectat.Id, cantitate, _produsSelectat.Pret);
                _vanzareService.ScadeStoc(idVanzare);

                MessageBox.Show(
                    $"✅ {_produsSelectat.Nume} x{cantitate} tastat!\nTotal: {total} MDL",
                    "Succes", MessageBoxButton.OK, MessageBoxImage.Information);

                txtCantitate.Text = "1";
                txtTotal.Text = "Total: 0 MDL";
                _produsSelectat = null;
            }
        }
    }
}