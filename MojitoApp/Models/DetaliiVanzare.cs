using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MojitoApp.Models
{
    public class DetaliiVanzare
    {
        public int Id { get; set; }
        public int IdVanzare { get; set; }
        public int IdProdus { get; set; }
        public string NumeProdus { get; set; } = "";
        public int Cantitate { get; set; }
        public decimal PretUnitar { get; set; }
    }
}