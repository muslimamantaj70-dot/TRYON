/* TryOn (SQL Server): логика тесті. 00_reset -> 01_schema -> 02_seed орындалған таза дерекқорда,
   03_queries-тен кейін, 05_update_delete-ке дейін іске қосыңыз.
   A бөлімі: деректер тұтастығы (JOIN-мен тексеру). Барлық қатар OK болуы керек.
   B бөлімі: қате болуы тиіс операторлар (шектеулер мен триггерлер). Қате келсе, тест өтті. ok=0 болмауы керек. */
USE TryOn;
GO
SET NOCOUNT ON;
GO

-- ===== A. Деректер тұтастығы =====
SELECT test, result FROM (
  SELECT 1 AS n, N'Тапсырыс сомасы = жолдар сомасы' AS test, CASE WHEN NOT EXISTS (SELECT 1 FROM dbo.orders o JOIN dbo.order_items oi ON oi.order_id = o.id GROUP BY o.id, o.total_amount HAVING o.total_amount <> SUM(oi.qty * oi.unit_price)) THEN 'OK' ELSE 'FAIL' END AS result
UNION ALL
  SELECT 2 AS n, N'Тапсырыс жолының атауы мен бағасы өніммен сәйкес (снимок)' AS test, CASE WHEN NOT EXISTS (SELECT 1 FROM dbo.order_items oi JOIN dbo.product_sizes ps ON ps.id = oi.product_size_id JOIN dbo.products p ON p.id = ps.product_id WHERE oi.product_name <> p.name OR oi.unit_price <> p.price) THEN 'OK' ELSE 'FAIL' END AS result
UNION ALL
  SELECT 3 AS n, N'Әр тауардың иесі «сатушы» рөлінде' AS test, CASE WHEN NOT EXISTS (SELECT 1 FROM dbo.products p JOIN dbo.users u ON u.id = p.seller_id JOIN dbo.roles r ON r.id = u.role_id WHERE r.code <> 'seller') THEN 'OK' ELSE 'FAIL' END AS result
UNION ALL
  SELECT 4 AS n, N'Дене профилі тек «клиент» рөліндегілерде' AS test, CASE WHEN NOT EXISTS (SELECT 1 FROM dbo.body_profiles b JOIN dbo.users u ON u.id = b.user_id JOIN dbo.roles r ON r.id = u.role_id WHERE r.code <> 'client') THEN 'OK' ELSE 'FAIL' END AS result
UNION ALL
  SELECT 5 AS n, N'Тауар түрі санатына сәйкес (футболка → Футболкалар және т.б.)' AS test, CASE WHEN NOT EXISTS (SELECT 1 FROM dbo.products p JOIN dbo.categories c ON c.id = p.category_id WHERE NOT ((p.garment_type = 'tee' AND c.slug = 't-shirts') OR (p.garment_type = 'sweater' AND c.slug = 'sweaters') OR (p.garment_type = 'shorts' AND c.slug = 'shorts') OR (p.garment_type = 'pants' AND c.slug = 'pants') OR (p.garment_type = 'sneakers' AND c.slug = 'sneakers'))) THEN 'OK' ELSE 'FAIL' END AS result
UNION ALL
  SELECT 6 AS n, N'Әр тауарда кемінде бір өлшем бар' AS test, CASE WHEN NOT EXISTS (SELECT 1 FROM dbo.products p WHERE NOT EXISTS (SELECT 1 FROM dbo.product_sizes ps WHERE ps.product_id = p.id)) THEN 'OK' ELSE 'FAIL' END AS result
UNION ALL
  SELECT 7 AS n, N'Әр тапсырыста кемінде бір жол бар' AS test, CASE WHEN NOT EXISTS (SELECT 1 FROM dbo.orders o WHERE NOT EXISTS (SELECT 1 FROM dbo.order_items oi WHERE oi.order_id = o.id)) THEN 'OK' ELSE 'FAIL' END AS result
UNION ALL
  SELECT 8 AS n, N'Төленген тапсырыстардың төлем сомасы тапсырыс сомасына тең' AS test, CASE WHEN NOT EXISTS (SELECT 1 FROM dbo.orders o WHERE o.status IN ('paid','packed','shipped','delivered') AND (SELECT COALESCE(SUM(pm.amount),0) FROM dbo.payments pm WHERE pm.order_id = o.id AND pm.status = 'paid') <> o.total_amount) THEN 'OK' ELSE 'FAIL' END AS result
UNION ALL
  SELECT 9 AS n, N'Қайтарылған шорты қоймаға оралды (6 дана: 6 − 1 + 1)' AS test, CASE WHEN (SELECT stock_qty FROM dbo.product_sizes WHERE sku = 'SHO-001-M') = 6 THEN 'OK' ELSE 'FAIL' END AS result
UNION ALL
  SELECT 10 AS n, N'Бас тартылған тапсырыстың қалдығы қайтты (2 дана)' AS test, CASE WHEN (SELECT stock_qty FROM dbo.product_sizes WHERE sku = 'SHO-002-XL') = 2 THEN 'OK' ELSE 'FAIL' END AS result
UNION ALL
  SELECT 11 AS n, N'Ақша қайтару сомасы = баға × саны' AS test, CASE WHEN NOT EXISTS (SELECT 1 FROM dbo.return_requests rr JOIN dbo.order_items oi ON oi.id = rr.order_item_id WHERE rr.status = 'refunded' AND rr.refund_amount <> oi.unit_price * rr.qty) THEN 'OK' ELSE 'FAIL' END AS result
UNION ALL
  SELECT 12 AS n, N'Аяқ киімнен басқа әр киім түрінде fit_rules ережесі бар' AS test, CASE WHEN NOT EXISTS (SELECT 1 FROM dbo.garment_types gt WHERE gt.slot <> 'shoes' AND NOT EXISTS (SELECT 1 FROM dbo.fit_rules r WHERE r.garment_type = gt.code)) THEN 'OK' ELSE 'FAIL' END AS result
UNION ALL
  SELECT 13 AS n, N'Жүйе ұсынған өлшем ешқашан «қысатын» емес' AS test, CASE WHEN NOT EXISTS (SELECT 1 FROM dbo.v_recommended_size r JOIN dbo.v_size_verdict v ON v.user_id = r.user_id AND v.product_size_id = r.product_size_id WHERE v.verdict = 'tight') THEN 'OK' ELSE 'FAIL' END AS result
) a ORDER BY n;
GO

-- ===== B. Қате болуы тиіс операторлар =====
CREATE OR ALTER PROCEDURE dbo.usp_t_expect_fail @title NVARCHAR(200), @sql NVARCHAR(MAX) AS
BEGIN
  DECLARE @raised BIT = 0, @msg NVARCHAR(300) = N'';
  BEGIN TRY
    EXEC sp_executesql @sql;
  END TRY
  BEGIN CATCH
    SET @raised = 1; SET @msg = LEFT(ERROR_MESSAGE(), 150);
  END CATCH
  INSERT INTO #r(ok, title, error_message) VALUES (@raised, @title, CASE WHEN @raised = 1 THEN @msg ELSE N'!!! қате күтілген еді, бірақ болмады' END);
END
GO

CREATE TABLE #r (id INT IDENTITY(1,1), ok BIT NOT NULL, title NVARCHAR(200) NOT NULL, error_message NVARCHAR(300) NOT NULL);

EXEC dbo.usp_t_expect_fail N'Сатушы емес пайдаланушы тауар қоса алмайды', N'INSERT INTO dbo.products(seller_id, category_id, garment_type, name, price) SELECT u.id, c.id, ''tee'', N''Тест'', 100 FROM dbo.users u CROSS JOIN dbo.categories c WHERE u.email = ''aigerim@example.com'' AND c.slug = ''t-shirts''';
EXEC dbo.usp_t_expect_fail N'Сатушының дене профилі болмайды', N'INSERT INTO dbo.body_profiles(user_id, height_cm, weight_kg, chest_cm, waist_cm, hip_cm) SELECT id, 170, 60, 90, 70, 95 FROM dbo.users WHERE email = ''seller1@tryon.kz''';
EXEC dbo.usp_t_expect_fail N'Сатушыға тапсырыс жасалмайды', N'INSERT INTO dbo.orders(customer_id, address_id) SELECT s.id, a.id FROM dbo.users s CROSS JOIN dbo.addresses a WHERE s.email = ''seller1@tryon.kz'' AND a.is_default = 1 AND a.user_id = (SELECT id FROM dbo.users WHERE email = ''aigerim@example.com'')';
EXEC dbo.usp_t_expect_fail N'Топтың өлшем кестесінде етек міндетті', N'INSERT INTO dbo.product_sizes(product_id, size_label, sku, chest_cm) SELECT id, ''XXL'', ''TEE-001-XXL'', 130 FROM dbo.products WHERE name = N''Футболка «TryOn» ақ''';
EXEC dbo.usp_t_expect_fail N'Аяқ киімге киім өлшемі қойылмайды', N'INSERT INTO dbo.product_sizes(product_id, size_label, sku, length_cm) SELECT id, ''M'', ''SNK-001-M'', 27 FROM dbo.products WHERE name = N''Кроссовка «Runner» ақ''';
EXEC dbo.usp_t_expect_fail N'Футболкаға аяқ киім өлшемі қойылмайды', N'INSERT INTO dbo.product_sizes(product_id, size_label, sku, chest_cm, hem_cm) SELECT id, ''42'', ''TEE-001-42'', 100, 100 FROM dbo.products WHERE name = N''Футболка «TryOn» ақ''';
EXEC dbo.usp_t_expect_fail N'Баға оң сан болуы керек (CHECK)', N'INSERT INTO dbo.products(seller_id, category_id, garment_type, name, price) SELECT u.id, c.id, ''tee'', N''Қате'', -5 FROM dbo.users u CROSS JOIN dbo.categories c WHERE u.email = ''seller1@tryon.kz'' AND c.slug = ''t-shirts''';
EXEC dbo.usp_t_expect_fail N'Email бірегей болуы керек (UNIQUE)', N'INSERT INTO dbo.users(email, password_hash, full_name, role_id) SELECT ''aigerim@example.com'', ''x'', N''Қайталама'', id FROM dbo.roles WHERE code = ''client''';
EXEC dbo.usp_t_expect_fail N'Жоқ пайдаланушыға себет қосуға болмайды (FOREIGN KEY)', N'INSERT INTO dbo.cart_items(user_id, product_size_id, qty) VALUES (999999, 1, 1)';
EXEC dbo.usp_t_expect_fail N'Қалдықтан артық тапсырыс беруге болмайды', N'INSERT INTO dbo.order_items(order_id, product_size_id, product_name, unit_price, qty) SELECT o.id, ps.id, N''x'', 100, 999 FROM dbo.orders o CROSS JOIN dbo.product_sizes ps WHERE o.status = ''new'' AND ps.sku = ''TEE-001-S''';
EXEC dbo.usp_t_expect_fail N'Тапсырысты жоюға болмайды', N'DELETE FROM dbo.orders WHERE status = ''cancelled''';
EXEC dbo.usp_t_expect_fail N'Мәртебені өткізіп жіберуге болмайды (new → delivered)', N'UPDATE dbo.orders SET status = ''delivered'' WHERE status = ''new''';
EXEC dbo.usp_t_expect_fail N'Жеткізілмеген тапсырыс бойынша қайтару жасалмайды', N'INSERT INTO dbo.return_requests(order_item_id, qty, reason) SELECT oi.id, 1, ''too_big'' FROM dbo.order_items oi JOIN dbo.orders o ON o.id = oi.order_id WHERE o.status = ''shipped''';
EXEC dbo.usp_t_expect_fail N'Сатып алғаннан артық қайтаруға болмайды', N'INSERT INTO dbo.return_requests(order_item_id, qty, reason) SELECT oi.id, 5, ''too_big'' FROM dbo.order_items oi JOIN dbo.orders o ON o.id = oi.order_id WHERE o.status = ''delivered'' AND oi.product_name LIKE N''Свитер%''';
EXEC dbo.usp_t_expect_fail N'fit_rules: бір түр мен аймаққа бір ғана ереже (UNIQUE)', N'INSERT INTO dbo.fit_rules(garment_type, zone, tight_below, loose_above) VALUES (''tee'', ''chest'', 1, 5)';
EXEC dbo.usp_t_expect_fail N'fit_rules: жоқ киім түріне ереже қосуға болмайды (FOREIGN KEY)', N'INSERT INTO dbo.fit_rules(garment_type, zone, tight_below, loose_above) VALUES (''hat'', ''chest'', 2, 10)';
EXEC dbo.usp_t_expect_fail N'fit_rules: «қысады» шегі «бос» шегінен кіші болуы керек (CHECK)', N'INSERT INTO dbo.fit_rules(garment_type, zone, tight_below, loose_above) VALUES (''sneakers'', ''hem'', 10, 2)';

SELECT id, ok, title, error_message FROM #r ORDER BY id;
SELECT ok, COUNT(*) AS n FROM #r GROUP BY ok ORDER BY ok;
GO
DROP TABLE IF EXISTS #r;
DROP PROCEDURE IF EXISTS dbo.usp_t_expect_fail;
GO
