using System.Windows;
using System.Windows.Controls;
using Microsoft.Data.SqlClient;
using MojitoApp.Helpers;
using MojitoApp.Services;

namespace MojitoApp.Views
{
    public partial class EuropeanPage : Page
    {
        private readonly VanzareService _vanzareService = new();
        private List<ProdusDisplay> _produse = new();

        public EuropeanPage()
        {
            InitializeComponent();
            IncarcaProduse();
        }

        private void IncarcaProduse()
        {
            _produse = new List<ProdusDisplay>();
            using var conn = DatabaseHelper.GetConnection();
            conn.Open();

            string query = @"SELECT P.id, P.nume, P.gramaj, P.pret,
                STUFF((SELECT ', ' + I.nume
                       FROM Produs_Ingrediente PI
                       INNER JOIN Ingrediente I ON PI.id_ingredient = I.id
                       WHERE PI.id_produs = P.id
                       FOR XML PATH(''), TYPE).value('.','NVARCHAR(MAX)'),1,2,'') AS Ingrediente
                FROM Produse P
                INNER JOIN Categorii C ON P.id_categorie = C.id
                WHERE C.tip = 'european'
                ORDER BY P.id";

            using var cmd = new SqlCommand(query, conn);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                _produse.Add(new ProdusDisplay
                {
                    Id = reader.GetInt32(0),
                    Nume = reader.GetString(1),
                    Gramaj = reader.IsDBNull(2) ? "" : reader.GetString(2),
                    Pret = reader.GetDecimal(3),
                    Ingrediente = reader.IsDBNull(4) ? "" : reader.GetString(4)
                });
            }
            listProduse.ItemsSource = _produse;
        }

        private void listProduse_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            ActualizeazaTotal();
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
            if (listProduse.SelectedItem is ProdusDisplay produs &&
                int.TryParse(txtCantitate.Text, out int cant))
            {
                txtTotal.Text = $"Total: {produs.Pret * cant} MDL";
            }
        }

        private void btnTasteaza_Click(object sender, RoutedEventArgs e)
        {
            if (listProduse.SelectedItem is not ProdusDisplay produs)
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

            decimal total = produs.Pret * cantitate;

            var rezultat = MessageBox.Show(
                $"Tastați: {produs.Nume}\nCantitate: {cantitate}\nTotal: {total} MDL",
                "Confirmare", MessageBoxButton.YesNo,
                MessageBoxImage.Question);

            if (rezultat == MessageBoxResult.Yes)
            {
                int idVanzare = _vanzareService.CreeazaVanzare(1, total);
                _vanzareService.AdaugaDetaliu(idVanzare, produs.Id, cantitate, produs.Pret);
                _vanzareService.ScadeStoc(idVanzare);

                MessageBox.Show($"✅ {produs.Nume} x{cantitate} tastat!\nTotal: {total} MDL",
                    "Succes", MessageBoxButton.OK, MessageBoxImage.Information);

                txtCantitate.Text = "1";
                txtTotal.Text = "Total: 0 MDL";
            }
        }
    }
}