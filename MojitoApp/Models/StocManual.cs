using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MojitoApp.Models
{
    public class StocManual
    {
        public int Id { get; set; }
        public string NumeProdus { get; set; } = "";
        public string Unitate { get; set; } = "";
        public decimal Cantitate { get; set; }
        public decimal CantitateMinima { get; set; }
    }
}