using System.Windows;
using System.Windows.Controls;
using MojitoApp.Helpers;
using MojitoApp.Models;
using MojitoApp.Services;
using MojitoApp.Views;

namespace MojitoApp
{
    public partial class MainWindow : Window
    {
        private readonly VanzareService _vanzareService = new();

        public MainWindow()
        {
            InitializeComponent();
            CosComenzi.CosActualizat += ActualizeazaCos;
            ActualizeazaCos();
        }

        private void ActualizeazaCos()
        {
            Dispatcher.Invoke(() =>
            {
                listCos.ItemsSource = null;
                listCos.ItemsSource = CosComenzi.Items;
                txtTotalCos.Text = $"{CosComenzi.Total:F2} MDL";
            });
        }

        private void Nav_Click(object sender, RoutedEventArgs e)
        {
            var btn = sender as Button;
            string tag = btn?.Tag?.ToString() ?? "";

            txtPagina.Text = tag switch
            {
                "european" => "Bucătărie Europeană",
                "japonez" => "Bucătărie Japoneză",
                "bar" => "Bar & Cocktailuri",
                "bauturi" => "Băuturi",
                "stocuri" => "Stocuri",
                "rapoarte" => "Rapoarte",
                "angajati" => "Angajați",
                _ => "Bun venit la Mojito"
            };

            MainFrame.Navigate(tag switch
            {
                "european" => new EuropeanPage(),
                "japonez" => new JapanesePage(),
                "bar" => new BarPage(),
                "bauturi" => new BauturiPage(),
                "stocuri" => new StocuriPage(),
                "angajati" => new AngajatiPage(),
                "import" => new ImportPage(),
                "rapoarte" => new RapoartePage(),
                _ => null
            });
        }

        private void btnFinalizare_Click(object sender, RoutedEventArgs e)
        {
            if (CosComenzi.Items.Count == 0)
            {
                MessageBox.Show("Coșul este gol!", "Atenție",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            var confirmare = MessageBox.Show(
                $"Finalizați comanda?\nTotal: {CosComenzi.Total:F2} MDL\nProduse: {CosComenzi.Items.Count}",
                "Confirmare", MessageBoxButton.YesNo, MessageBoxImage.Question);

            if (confirmare == MessageBoxResult.Yes)
            {
                int idVanzare = _vanzareService.CreeazaVanzare(1, CosComenzi.Total);

                foreach (var item in CosComenzi.Items)
                {
                    _vanzareService.AdaugaDetaliu(idVanzare, item.IdProdus,
                        item.Cantitate, item.Pret);
                }

                _vanzareService.ScadeStoc(idVanzare);

                MessageBox.Show(
                    $"✅ Comanda finalizată!\nTotal: {CosComenzi.Total:F2} MDL",
                    "Succes", MessageBoxButton.OK, MessageBoxImage.Information);

                CosComenzi.Goleste();
            }
        }

        private void btnGolesteCos_Click(object sender, RoutedEventArgs e)
        {
            if (CosComenzi.Items.Count == 0) return;

            var confirmare = MessageBox.Show("Goliți coșul?", "Confirmare",
                MessageBoxButton.YesNo, MessageBoxImage.Question);

            if (confirmare == MessageBoxResult.Yes)
                CosComenzi.Goleste();
        }

        private void Logout_Click(object sender, RoutedEventArgs e)
        {
            CosComenzi.Goleste();
            var login = new Views.LoginWindow();
            login.Show();
            this.Close();
        }
    }
}