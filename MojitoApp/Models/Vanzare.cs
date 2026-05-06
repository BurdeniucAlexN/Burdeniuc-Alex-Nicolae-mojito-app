using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using System;

namespace MojitoApp.Models
{
    public class Vanzare
    {
        public int Id { get; set; }
        public int IdAngajat { get; set; }
        public DateTime DataOra { get; set; }
        public decimal Total { get; set; }
    }
}