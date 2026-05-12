using System.Windows;
using System.Windows.Controls;
using MojitoApp.Views;

namespace MojitoApp
{
    public partial class MainWindow : Window
    {
        public MainWindow()
        {
            InitializeComponent();
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
                _ => null
            });
        }

        private void Logout_Click(object sender, RoutedEventArgs e)
        {
            var login = new Views.LoginWindow();
            login.Show();
            this.Close();
        }
    }
}