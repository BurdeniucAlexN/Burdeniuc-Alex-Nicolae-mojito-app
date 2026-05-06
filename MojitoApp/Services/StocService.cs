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
    public class StocService
    {
        public List<Stoc> GetAllStocuri()
        {
            var lista = new List<Stoc>();
            using var conn = DatabaseHelper.GetConnection();
            conn.Open();
            string query = @"SELECT S.id, S.id_ingredient, I.nume,
                            S.cantitate_disponibila, S.cantitate_minima,
                            I.unitate_masura
                            FROM Stocuri S
                            INNER JOIN Ingrediente I ON S.id_ingredient = I.id
                            ORDER BY I.nume";
            using var cmd = new SqlCommand(query, conn);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                lista.Add(new Stoc
                {
                    Id = reader.GetInt32(0),
                    IdIngredient = reader.GetInt32(1),
                    NumeIngredient = reader.GetString(2),
                    CantitateDisponibila = reader.GetDecimal(3),
                    CantitateMinima = reader.GetDecimal(4),
                    UnitateMasura = reader.GetString(5)
                });
            }
            return lista;
        }

        public List<Stoc> GetStocCritic()
        {
            var lista = new List<Stoc>();
            using var conn = DatabaseHelper.GetConnection();
            conn.Open();
            string query = @"SELECT S.id, S.id_ingredient, I.nume,
                            S.cantitate_disponibila, S.cantitate_minima,
                            I.unitate_masura
                            FROM Stocuri S
                            INNER JOIN Ingrediente I ON S.id_ingredient = I.id
                            WHERE S.cantitate_disponibila <= S.cantitate_minima";
            using var cmd = new SqlCommand(query, conn);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                lista.Add(new Stoc
                {
                    Id = reader.GetInt32(0),
                    IdIngredient = reader.GetInt32(1),
                    NumeIngredient = reader.GetString(2),
                    CantitateDisponibila = reader.GetDecimal(3),
                    CantitateMinima = reader.GetDecimal(4),
                    UnitateMasura = reader.GetString(5)
                });
            }
            return lista;
        }

        public List<StocManual> GetStocManual()
        {
            var lista = new List<StocManual>();
            using var conn = DatabaseHelper.GetConnection();
            conn.Open();
            string query = "SELECT id, nume_produs, unitate, cantitate, cantitate_minima FROM Stoc_Manual ORDER BY nume_produs";
            using var cmd = new SqlCommand(query, conn);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                lista.Add(new StocManual
                {
                    Id = reader.GetInt32(0),
                    NumeProdus = reader.GetString(1),
                    Unitate = reader.GetString(2),
                    Cantitate = reader.GetDecimal(3),
                    CantitateMinima = reader.GetDecimal(4)
                });
            }
            return lista;
        }
    }
}