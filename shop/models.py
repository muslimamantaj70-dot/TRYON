"""
TryOn: Django модельдері (shop/models.py)

Бұл модельдер MSSQL-дегі 14 кестеге (docs/diagrams/03_er.puml) сәйкес келеді.
managed = False: кестелерді Django құрмайды және өзгертпейді, оларды
database/schema.sql құрады. Django тек оқиды және жазады.
"""
from django.db import models


# ---------- Пайдаланушылар ----------

class Role(models.Model):
    id = models.IntegerField(primary_key=True)        # roles.id IDENTITY емес, қолмен беріледі
    code = models.CharField(max_length=20, unique=True)
    name = models.CharField(max_length=50)

    class Meta:
        managed = False
        db_table = "roles"
        verbose_name = "Рөл"
        verbose_name_plural = "Рөлдер"

    def __str__(self):
        return self.name


class User(models.Model):
    email = models.CharField(max_length=255, unique=True)
    password_hash = models.CharField(max_length=255)
    full_name = models.CharField(max_length=150)
    phone = models.CharField(max_length=30, null=True, blank=True)
    role = models.ForeignKey(Role, on_delete=models.PROTECT)              # role_id
    shop_name = models.CharField(max_length=150, null=True, blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        managed = False
        db_table = "users"
        verbose_name = "Пайдаланушы"
        verbose_name_plural = "Пайдаланушылар (TryOn)"

    def __str__(self):
        return self.full_name


class BodyProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE,
                                primary_key=True, related_name="body")  # user_id (PK + FK)
    sex = models.CharField(max_length=1, default="n")   # m / f / n
    height_cm = models.IntegerField()
    weight_kg = models.DecimalField(max_digits=5, decimal_places=1)
    chest_cm = models.DecimalField(max_digits=5, decimal_places=1)
    waist_cm = models.DecimalField(max_digits=5, decimal_places=1)
    hip_cm = models.DecimalField(max_digits=5, decimal_places=1)
    is_manual = models.BooleanField(default=False)

    class Meta:
        managed = False
        db_table = "body_profiles"
        verbose_name = "Дене профилі"
        verbose_name_plural = "Дене профильдері"

    def __str__(self):
        return f"{self.user} ({self.height_cm} см)"


class Address(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="addresses")
    city = models.CharField(max_length=100)
    street = models.CharField(max_length=150)
    house = models.CharField(max_length=20)
    apartment = models.CharField(max_length=20, null=True, blank=True)
    recipient_phone = models.CharField(max_length=30)
    is_default = models.BooleanField(default=False)

    class Meta:
        managed = False
        db_table = "addresses"
        verbose_name = "Мекенжай"
        verbose_name_plural = "Мекенжайлар"

    def __str__(self):
        return f"{self.city}, {self.street} {self.house}"


# ---------- Каталог және отыру ережелері ----------

class Category(models.Model):
    name = models.CharField(max_length=100)
    slug = models.CharField(max_length=100, unique=True)
    parent = models.ForeignKey("self", on_delete=models.PROTECT,
                               null=True, blank=True, related_name="children")  # parent_id

    class Meta:
        managed = False
        db_table = "categories"
        verbose_name = "Санат"
        verbose_name_plural = "Санаттар"

    def __str__(self):
        return self.name


class GarmentType(models.Model):
    code = models.CharField(max_length=20, primary_key=True)   # tee, sweater, shorts, pants
    name = models.CharField(max_length=50)
    slot = models.CharField(max_length=10)                     # top / bottom / shoes

    class Meta:
        managed = False
        db_table = "garment_types"
        verbose_name = "Киім түрі"
        verbose_name_plural = "Киім түрлері"

    def __str__(self):
        return self.name


class FitRule(models.Model):
    garment_type = models.ForeignKey(GarmentType, on_delete=models.CASCADE,
                                     db_column="garment_type", related_name="rules")
    zone = models.CharField(max_length=10)                     # chest, hem, waist, hip, thigh
    tight_below = models.DecimalField(max_digits=4, decimal_places=1)
    loose_above = models.DecimalField(max_digits=4, decimal_places=1)

    class Meta:
        managed = False
        db_table = "fit_rules"
        verbose_name = "Отыру ережесі"
        verbose_name_plural = "Отыру ережелері"
        unique_together = (("garment_type", "zone"),)

    def __str__(self):
        return f"{self.garment_type_id}: {self.zone} ({self.tight_below}…{self.loose_above})"


class Product(models.Model):
    seller = models.ForeignKey(User, on_delete=models.PROTECT, related_name="products")  # seller_id
    category = models.ForeignKey(Category, on_delete=models.PROTECT)
    garment_type = models.ForeignKey(GarmentType, on_delete=models.PROTECT,
                                     db_column="garment_type")
    name = models.CharField(max_length=200)
    description = models.CharField(max_length=1000, null=True, blank=True)
    price = models.IntegerField()
    color_hex = models.CharField(max_length=7, default="#cccccc")
    pattern = models.CharField(max_length=10, default="solid")      # solid / stripe / check / dot
    print_kind = models.CharField(max_length=10, null=True, blank=True)  # logo / star / image
    image_path = models.CharField(max_length=300, null=True, blank=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        managed = False
        db_table = "products"
        verbose_name = "Тауар"
        verbose_name_plural = "Тауарлар"

    def __str__(self):
        return self.name


class ProductSize(models.Model):
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name="sizes")
    size_label = models.CharField(max_length=10)               # S, M, L, XL
    sku = models.CharField(max_length=40, unique=True)
    chest_cm = models.DecimalField(max_digits=5, decimal_places=1, null=True)
    hem_cm = models.DecimalField(max_digits=5, decimal_places=1, null=True)
    waist_cm = models.DecimalField(max_digits=5, decimal_places=1, null=True)
    hip_cm = models.DecimalField(max_digits=5, decimal_places=1, null=True)
    thigh_cm = models.DecimalField(max_digits=5, decimal_places=1, null=True)
    length_cm = models.DecimalField(max_digits=5, decimal_places=1, null=True)
    stock_qty = models.IntegerField(default=0)

    class Meta:
        managed = False
        db_table = "product_sizes"
        verbose_name = "Тауар өлшемі"
        verbose_name_plural = "Тауар өлшемдері"
        unique_together = (("product", "size_label"),)

    def __str__(self):
        return f"{self.product} — {self.size_label}"

    def has_stock(self, qty=1):
        return self.stock_qty >= qty


# ---------- Сатып алу ----------

class CartItem(models.Model):
    # 01_schema.sql-де cart_items кестесіне id INT IDENTITY қосылуы керек
    # (UNIQUE (user_id, product_size_id) қалады), әйтпесе Django id бағанын таппайды.
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="cart")
    product_size = models.ForeignKey(ProductSize, on_delete=models.CASCADE)
    qty = models.IntegerField()

    class Meta:
        managed = False
        db_table = "cart_items"
        verbose_name = "Себет жолы"
        verbose_name_plural = "Себет"
        unique_together = (("user", "product_size"),)

    def __str__(self):
        return f"{self.user}: {self.product_size} ×{self.qty}"


class Order(models.Model):
    customer = models.ForeignKey(User, on_delete=models.PROTECT, related_name="orders")
    address = models.ForeignKey(Address, on_delete=models.PROTECT)
    manager = models.ForeignKey(User, on_delete=models.PROTECT, null=True, blank=True,
                                related_name="managed_orders")
    status = models.CharField(max_length=10, default="new")    # new, paid, packed, shipped, delivered, cancelled
    total_amount = models.IntegerField(default=0)               # order_items триггері есептейді
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        managed = False
        db_table = "orders"
        verbose_name = "Тапсырыс"
        verbose_name_plural = "Тапсырыстар"

    def __str__(self):
        return f"Тапсырыс №{self.pk} — {self.customer}"


class OrderItem(models.Model):
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name="items")
    product_size = models.ForeignKey(ProductSize, on_delete=models.PROTECT)
    product_name = models.CharField(max_length=200)
    unit_price = models.IntegerField()
    qty = models.IntegerField()

    class Meta:
        managed = False
        db_table = "order_items"
        verbose_name = "Тапсырыс жолы"
        verbose_name_plural = "Тапсырыс жолдары"
        unique_together = (("order", "product_size"),)

    def __str__(self):
        return f"{self.product_name} ×{self.qty}"

    def line_total(self):
        return self.unit_price * self.qty


class Payment(models.Model):
    order = models.ForeignKey(Order, on_delete=models.PROTECT, related_name="payments")
    amount = models.IntegerField()
    method = models.CharField(max_length=10)                   # card / kaspi / cash
    status = models.CharField(max_length=10, default="pending")  # pending / paid / failed
    paid_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = "payments"
        verbose_name = "Төлем"
        verbose_name_plural = "Төлемдер"

    def __str__(self):
        return f"Төлем №{self.pk}: {self.amount} ₸ ({self.status})"


class ReturnRequest(models.Model):
    order_item = models.ForeignKey(OrderItem, on_delete=models.PROTECT, related_name="returns")
    qty = models.IntegerField()
    reason = models.CharField(max_length=20)                   # too_small, too_big, defect, not_as_shown, changed_mind
    comment = models.CharField(max_length=500, null=True, blank=True)
    status = models.CharField(max_length=10, default="requested")  # requested, approved, rejected, refunded
    handled_by = models.ForeignKey(User, on_delete=models.PROTECT, null=True, blank=True,
                                   db_column="handled_by", related_name="handled_returns")
    refund_amount = models.IntegerField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        managed = False
        db_table = "return_requests"
        verbose_name = "Қайтару өтінімі"
        verbose_name_plural = "Қайтару өтінімдері"

    def __str__(self):
        return f"Қайтару №{self.pk}: {self.order_item} ({self.status})"
