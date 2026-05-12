using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using Microsoft.Data.SqlClient;
using MojitoApp.Helpers;
using MojitoApp.Models;
using MojitoApp.Services;

namespace MojitoApp.Views
{
    public class StocDisplay
    {
        public int Id { get; set; }
        public int IdIngredient { get; set; }
        public string NumeIngredient { get; set; } = "";
        public decimal CantitateDisponibila { get; set; }
        public decimal CantitateMinima { get; set; }
        public string UnitateMasura { get; set; } = "";
        public string Status => CantitateDisponibila <= CantitateMinima ? "⚠ CRITIC" : "✓ OK";
        public string StatusColor => CantitateDisponibila <= CantitateMinima ? "#E74C3C" : "#2ECC71";
    }

    public class StocManualDisplay
    {
        public int Id { get; set; }
        public string NumeProdus { get; set; } = "";
        public string Unitate { get; set; } = "";
        public decimal Cantitate { get; set; }
        public decimal CantitateMinima { get; set; }
        public string Status => Cantitate <= CantitateMinima ? "⚠ CRITIC" : "✓ OK";
        public string StatusColor => Cantitate <= CantitateMinima ? "#E74C3C" : "#2ECC71";
    }

    public partial class StocuriPage : Page
    {
        private readonly StocService _stocService = new();
        private StocDisplay? _stocSelectat = null;
        private StocManualDisplay? _stocManualSelectat = null;

        public StocuriPage()
        {
            InitializeComponent();
            IncarcaDate();
            listStocuri.SelectionChanged += (s, e) =>
            {
                if (listStocuri.SelectedItem is StocDisplay sd)
                {
                    _stocSelectat = sd;
                    txtIngredientSelectat.Text = $"Ingredient: {sd.NumeIngredient} ({sd.CantitateDisponibila} {sd.UnitateMasura})";
                    txtIngredientSelectat.Foreground = new SolidColorBrush(Colors.White);
                }
            };
            listStocManual.SelectionChanged += (s, e) =>
            {
                if (listStocManual.SelectedItem is StocManualDisplay sm)
                {
                    _stocManualSelectat = sm;
                    txtProdusManualSelectat.Text = $"Produs: {sm.NumeProdus} ({sm.Cantitate} {sm.Unitate})";
                    txtProdusManualSelectat.Foreground = new SolidColorBrush(Colors.White);
                }
            };
        }

        private void IncarcaDate()
        {
            IncarcaStocuri();
            IncarcaStocManual();
            IncarcaStocCritic();
        }

        private void IncarcaStocuri()
        {
            var lista = new List<StocDisplay>();
            using var conn = DatabaseHelper.GetConnection();
            conn.Open();
            string query = @"SELECT S.id, S.id_ingredient, I.nume,
                            S.cantitate_disponibila, S.cantitate_minima, I.unitate_masura
                            FROM Stocuri S
                            INNER JOIN Ingrediente I ON S.id_ingredient = I.id
                            ORDER BY I.nume";
            using var cmd = new SqlCommand(query, conn);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                lista.Add(new StocDisplay
                {
                    Id = reader.GetInt32(0),
                    IdIngredient = reader.GetInt32(1),
                    NumeIngredient = reader.GetString(2),
                    CantitateDisponibila = reader.GetDecimal(3),
                    CantitateMinima = reader.GetDecimal(4),
                    UnitateMasura = reader.GetString(5)
                });
            }
            listStocuri.ItemsSource = lista;
        }

        private void IncarcaStocManual()
        {
            var lista = new List<StocManualDisplay>();
            using var conn = DatabaseHelper.GetConnection();
            conn.Open();
            string query = "SELECT id, nume_produs, unitate, cantitate, cantitate_minima FROM Stoc_Manual ORDER BY nume_produs";
            using var cmd = new SqlCommand(query, conn);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                lista.Add(new StocManualDisplay
                {
                    Id = reader.GetInt32(0),
                    NumeProdus = reader.GetString(1),
                    Unitate = reader.GetString(2),
                    Cantitate = reader.GetDecimal(3),
                    CantitateMinima = reader.GetDecimal(4)
                });
            }
            listStocManual.ItemsSource = lista;
        }

        private void IncarcaStocCritic()
        {
            var lista = new List<StocDisplay>();
            using var conn = DatabaseHelper.GetConnection();
            conn.Open();
            string query = @"SELECT S.id, S.id_ingredient, I.nume,
                            S.cantitate_disponibila, S.cantitate_minima, I.unitate_masura
                            FROM Stocuri S
                            INNER JOIN Ingrediente I ON S.id_ingredient = I.id
                            WHERE S.cantitate_disponibila <= S.cantitate_minima
                            ORDER BY S.cantitate_disponibila ASC";
            using var cmd = new SqlCommand(query, conn);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                lista.Add(new StocDisplay
                {
                    Id = reader.GetInt32(0),
                    IdIngredient = reader.GetInt32(1),
                    NumeIngredient = reader.GetString(2),
                    CantitateDisponibila = reader.GetDecimal(3),
                    CantitateMinima = reader.GetDecimal(4),
                    UnitateMasura = reader.GetString(5)
                });
            }
            listStocCritic.ItemsSource = lista;
        }

        private void btnAdaugaStoc_Click(object sender, RoutedEventArgs e)
        {
            if (_stocSelectat == null)
            {
                MessageBox.Show("Selectați un ingredient!", "Atenție",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            if (!decimal.TryParse(txtCantitateNoua.Text.Replace(",", "."),
                System.Globalization.NumberStyles.Any,
                System.Globalization.CultureInfo.InvariantCulture,
                out decimal cantitate) || cantitate <= 0)
            {
                MessageBox.Show("Introduceți o cantitate validă!", "Atenție",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            using var conn = DatabaseHelper.GetConnection();
            conn.Open();
            string query = @"UPDATE Stocuri 
                            SET cantitate_disponibila = cantitate_disponibila + @c
                            WHERE id_ingredient = @i";
            using var cmd = new SqlCommand(query, conn);
            cmd.Parameters.AddWithValue("@c", cantitate);
            cmd.Parameters.AddWithValue("@i", _stocSelectat.IdIngredient);
            cmd.ExecuteNonQuery();

            MessageBox.Show($"✅ Adăugat {cantitate} {_stocSelectat.UnitateMasura} la {_stocSelectat.NumeIngredient}!",
                "Succes", MessageBoxButton.OK, MessageBoxImage.Information);

            txtCantitateNoua.Clear();
            _stocSelectat = null;
            txtIngredientSelectat.Text = "Selectați un ingredient din listă";
            IncarcaDate();
        }

        private void btnActualizeazaManual_Click(object sender, RoutedEventArgs e)
        {
            if (_stocManualSelectat == null)
            {
                MessageBox.Show("Selectați un produs!", "Atenție",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            if (!decimal.TryParse(txtCantitateManual.Text.Replace(",", "."),
                System.Globalization.NumberStyles.Any,
                System.Globalization.CultureInfo.InvariantCulture,
                out decimal cantitate) || cantitate < 0)
            {
                MessageBox.Show("Introduceți o cantitate validă!", "Atenție",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            using var conn = DatabaseHelper.GetConnection();
            conn.Open();
            string query = @"UPDATE Stoc_Manual 
                            SET cantitate = @c, data_actualizare = GETDATE()
                            WHERE id = @i";
            using var cmd = new SqlCommand(query, conn);
            cmd.Parameters.AddWithValue("@c", cantitate);
            cmd.Parameters.AddWithValue("@i", _stocManualSelectat.Id);
            cmd.ExecuteNonQuery();

            MessageBox.Show($"✅ Stoc actualizat: {_stocManualSelectat.NumeProdus} = {cantitate} {_stocManualSelectat.Unitate}",
                "Succes", MessageBoxButton.OK, MessageBoxImage.Information);

            txtCantitateManual.Clear();
            _stocManualSelectat = null;
            txtProdusManualSelectat.Text = "Selectați un produs din listă";
            IncarcaDate();
        }

        private void btnRefresh_Click(object sender, RoutedEventArgs e)
        {
            IncarcaDate();
            MessageBox.Show("Lista actualizată!", "Info",
                MessageBoxButton.OK, MessageBoxImage.Information);
        }
    }
}