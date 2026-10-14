import pyodbc

conn = pyodbc.connect(
    "DRIVER={ODBC Driver 18 for SQL Server};"
    r"SERVER=MUKDUCK\SQLEXPRESS;"
    "DATABASE=TryOn;"
    "Trusted_Connection=yes;"
    "TrustServerCertificate=yes;"
)
cur = conn.cursor()
cur.execute("SELECT COUNT(*) FROM dbo.products")
print("Тауар саны:", cur.fetchone()[0])
conn.close()