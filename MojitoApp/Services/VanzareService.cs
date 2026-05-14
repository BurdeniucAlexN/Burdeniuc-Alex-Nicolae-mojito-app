using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using Microsoft.Data.SqlClient;
using MojitoApp.Helpers;
using MojitoApp.Models;

namespace MojitoApp.Services
{
    public class VanzareService
    {
        public int CreeazaVanzare(decimal total)
        {
            using var conn = DatabaseHelper.GetConnection();
            conn.Open();
            string query = @"INSERT INTO Vanzari (id_angajat, total) 
                    VALUES (@a, @t);
                    SELECT SCOPE_IDENTITY();";
            using var cmd = new SqlCommand(query, conn);
            cmd.Parameters.AddWithValue("@a", SessionManager.IdAngajat);
            cmd.Parameters.AddWithValue("@t", total);
            return Convert.ToInt32(cmd.ExecuteScalar());
        }

        public void AdaugaDetaliu(int idVanzare, int idProdus, int cantitate, decimal pret)
        {
            using var conn = DatabaseHelper.GetConnection();
            conn.Open();
            string query = @"INSERT INTO Detalii_Vanzari 
                            (id_vanzare, id_produs, cantitate, pret_unitar)
                            VALUES (@v, @p, @c, @pr)";
            using var cmd = new SqlCommand(query, conn);
            cmd.Parameters.AddWithValue("@v", idVanzare);
            cmd.Parameters.AddWithValue("@p", idProdus);
            cmd.Parameters.AddWithValue("@c", cantitate);
            cmd.Parameters.AddWithValue("@pr", pret);
            cmd.ExecuteNonQuery();
        }

        public void ScadeStoc(int idVanzare)
        {
            using var conn = DatabaseHelper.GetConnection();
            conn.Open();
            using var cmd = new SqlCommand("sp_ScadeStocDupaVanzare", conn);
            cmd.CommandType = System.Data.CommandType.StoredProcedure;
            cmd.Parameters.AddWithValue("@id_vanzare", idVanzare);
            cmd.ExecuteNonQuery();
        }
    }
}