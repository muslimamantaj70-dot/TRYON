"""
TryOn: әкімші панелі (shop/admin.py).
Негізгі кестелерге ыңғайлы тізім бағандары, сүзгі және іздеу қосылған.
"""
from django.apps import apps
from django.contrib import admin

from .models import FitRule, Order, OrderItem, Product, ProductSize, ReturnRequest, User


class ProductSizeInline(admin.TabularInline):
    model = ProductSize
    extra = 0


@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = ("name", "garment_type", "category", "seller", "price", "is_active")
    list_filter = ("garment_type", "category", "is_active")
    search_fields = ("name",)
    inlines = [ProductSizeInline]        # өлшем кестесі тауардың ішінде


@admin.register(ProductSize)
class ProductSizeAdmin(admin.ModelAdmin):
    list_display = ("sku", "product", "size_label", "stock_qty")
    list_filter = ("size_label",)
    search_fields = ("sku", "product__name")


@admin.register(FitRule)
class FitRuleAdmin(admin.ModelAdmin):
    list_display = ("garment_type", "zone", "tight_below", "loose_above")
    list_filter = ("garment_type",)


class OrderItemInline(admin.TabularInline):
    model = OrderItem
    extra = 0


@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):
    list_display = ("id", "customer", "status", "total_amount", "manager", "created_at")
    list_filter = ("status",)
    readonly_fields = ("total_amount",)  # соманы SQL триггері есептейді
    inlines = [OrderItemInline]


@admin.register(ReturnRequest)
class ReturnRequestAdmin(admin.ModelAdmin):
    list_display = ("id", "order_item", "qty", "reason", "status", "handled_by", "refund_amount")
    list_filter = ("status", "reason")


@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = ("full_name", "email", "role", "shop_name", "is_active")
    list_filter = ("role", "is_active")
    search_fields = ("full_name", "email")


# Қалған кестелер қарапайым түрде тіркеледі
for model in apps.get_app_config("shop").get_models():
    if not admin.site.is_registered(model):
        admin.site.register(model)


# Әкімші панелінің атауы
admin.site.site_header = "TryOn Admin"        # жоғарғы сол жақтағы үлкен жазу
admin.site.site_title = "TryOn Admin"         # браузер қойындысындағы атау
admin.site.index_title = "TryOn Dashboard"    # басты беттегі тақырып
