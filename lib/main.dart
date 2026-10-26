import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const AuthGate());
}

// --- Auth Gate: Kullanıcı oturumu kontrolü ---
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Trend Store',
      theme: ThemeData(primarySwatch: Colors.orange),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            return const HomeScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}

// --- Product Model ---
class Product {
  final String id;
  final String name;
  final double price;
  final String category;
  final String description;
  final String imageUrl;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.description,
    required this.imageUrl,
  });

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      category: (data['category'] ?? '').toString().trim(),
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
    );
  }
}

// --- Payment Result (Sahte Ödeme) ---
class PaymentResult {
  final bool success;
  final String method; // 'card'
  final String brand; // Visa/Mastercard/Amex/Unknown
  final String last4;
  final DateTime paidAt;

  PaymentResult({
    required this.success,
    required this.method,
    required this.brand,
    required this.last4,
    required this.paidAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'method': method,
      'brand': brand,
      'last4': last4,
      'paidAt': Timestamp.fromDate(paidAt),
      'provider': 'fake-gateway',
      'status': success ? 'paid' : 'failed',
      'mock': true,
    };
  }
}

// --- HOME ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedCategory = 'Tümü'; // Başlangıçta tüm ürünler gösterilsin
  String searchQuery = ''; // Arama sorgusu
  String favoritesSearchQuery = ''; // Favoriler arama sorgusu

  final TextEditingController _searchController =
      TextEditingController(); // Arama çubuğu için kontrolör
  final TextEditingController
  _favoritesSearchController = // Favoriler arama çubuğu için kontrolör
      TextEditingController();

  int _selectedIndex =
      0; // 0: Home, 1: Favorites, 2: Cart, 3: Orders, 4: Profile
  Set<String> favoriteProductIds = {}; // Favori ürün ID'leri
  List<Product> cart = []; // Sepet ürünleri
  Map<String, dynamic> userProfile = {}; // Kullanıcı profili bilgileri

  @override
  void initState() {
    super.initState();
    loadFavorites();
    loadCart();
    loadUserProfile();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _favoritesSearchController.dispose();
    super.dispose();
  }

  // Favorileri Firestore'dan yükle
  Future<void> loadFavorites() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .get();

    setState(() {
      favoriteProductIds = snapshot.docs.map((doc) => doc.id).toSet();
    });
  }

  // Sepeti Firestore'dan yükle
  Future<void> loadCart() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('cart')
        .get();

    setState(() {
      cart = snapshot.docs.map((doc) {
        final data = doc.data();
        return Product(
          id: doc.id,
          name: data['name'] ?? '',
          price: (data['price'] ?? 0).toDouble(),
          category: data['category'] ?? '',
          description: data['description'] ?? '',
          imageUrl: data['imageUrl'] ?? '',
        );
      }).toList();
    });
  }

  // Kullanıcı profilini Firestore'dan yükle
  Future<void> loadUserProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    if (doc.exists) {
      setState(() {
        userProfile = doc.data() ?? {};
      });
    }
  }

  // Kullanıcı profilini Firestore'a kaydet
  Future<void> saveUserProfile(Map<String, dynamic> profile) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set(profile, SetOptions(merge: true));

    setState(() {
      userProfile = profile;
    });
  }

  Future<void> addFavorite(Product product) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(product.id);
    await doc.set({
      'name': product.name,
      'price': product.price,
      'category': product.category,
      'description': product.description,
      'imageUrl': product.imageUrl,
    });
  }

  Future<void> removeFavorite(String productId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(productId);
    await doc.delete();
  }

  Future<void> addToCart(Product product) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('cart')
        .doc(product.id);
    await doc.set({
      'name': product.name,
      'price': product.price,
      'category': product.category,
      'description': product.description,
      'imageUrl': product.imageUrl,
    });
  }

  Future<void> removeFromCart(String productId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('cart')
        .doc(productId);
    await doc.delete();
  }

  bool _matchesSearch(Product p) {
    // Arama sorgusuna göre ürünleri filtrele
    final q = searchQuery
        .trim()
        .toLowerCase(); // Kullanıcı arama çubuğuna bir şey yazdığında, bu fonksiyon her ürün (Product p) için çalışır.
    if (q.isEmpty)
      return true; // Eğer arama sorgusu boşsa, tüm ürünler eşleşir.
    return p.name.toLowerCase().contains(
          q,
        ) || // eğer sorgu boş değilse ürünün adı açıklaması kategorisi gelir
        p.description.toLowerCase().contains(q) ||
        p.category.toLowerCase().contains(q);
  }

  bool _matchesFavoritesSearch(Product p) {
    // Favoriler arama sorgusuna göre ürünleri filtrele
    final q = favoritesSearchQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    return p.name.toLowerCase().contains(q) ||
        p.description.toLowerCase().contains(q) ||
        p.category.toLowerCase().contains(q);
  }

  PreferredSizeWidget _buildHomeAppBar() {
    // Anasayfa için özel AppBar
    return AppBar(
      title: const Text('Trend Store'),
      backgroundColor: const Color(0xFFe48ebe),
      foregroundColor: const Color(0xFF393046),
      elevation: 1,
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Ürün ara...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          searchQuery = '';
                        });
                        _searchController.clear();
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 0,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.orange.shade100,
                  width: 1.2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.orange.shade100,
                  width: 1.2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color.fromARGB(255, 255, 160, 231),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildFavoritesAppBar() {
    return AppBar(
      title: const Text('Favoriler'),
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(58),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: TextField(
            controller: _favoritesSearchController,
            onChanged: (value) {
              setState(() {
                favoritesSearchQuery = value;
              });
            },
            decoration: InputDecoration(
              // Favoriler arama çubuğu
              hintText: 'Favorilerde ara...',
              prefixIcon: const Icon(Icons.search), // Arama ikonu
              suffixIcon:
                  favoritesSearchQuery
                      .isNotEmpty // Arama sorgusu varsa temizleme ikonu
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          favoritesSearchQuery = '';
                        });
                        _favoritesSearchController.clear();
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 0,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.black12, width: 1.2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.black12, width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.black45, width: 1.5),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Siparişler (tam ekran)
    if (_selectedIndex == 3) {
      return OrdersScreen(
        onBack: () {
          setState(() {
            _selectedIndex = 0;
          });
        },
      );
    }

    // Profil ekranı
    if (_selectedIndex == 4) {
      final user = FirebaseAuth.instance.currentUser;

      return Scaffold(
        appBar: AppBar(
          title: const Text('Profil'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.orange.shade200,
                      child: Icon(
                        Icons.person,
                        size: 60,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      userProfile['firstName'] != null &&
                              userProfile['lastName'] != null
                          ? '${userProfile['firstName']} ${userProfile['lastName']}'
                          : 'Kullanıcı',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      user?.email ?? 'Tanımlanmamış Kullanıcı',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _buildSectionTitle('Kişisel Bilgiler'),
              _buildProfileCard([
                _buildProfileItem(
                  icon: Icons.person,
                  title: 'Ad',
                  value: userProfile['firstName'] ?? 'Belirtilmemiş',
                  onTap: () => _showEditDialog('firstName', 'Adınızı girin'),
                ),
                _buildProfileItem(
                  icon: Icons.person_outline,
                  title: 'Soyad',
                  value: userProfile['lastName'] ?? 'Belirtilmemiş',
                  onTap: () => _showEditDialog('lastName', 'Soyadınızı girin'),
                ),
                _buildProfileItem(
                  icon: Icons.phone,
                  title: 'Telefon',
                  value: userProfile['phone'] ?? 'Belirtilmemiş',
                  onTap: () =>
                      _showEditDialog('phone', 'Telefon numaranızı girin'),
                ),
                _buildProfileItem(
                  icon: Icons.location_on,
                  title: 'Adres',
                  value: userProfile['address'] ?? 'Belirtilmemiş',
                  onTap: () => _showEditDialog('address', 'Adresinizi girin'),
                ),
              ]),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text("Çıkış Yap"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: buildBottomNavBar(),
      );
    }

    // Favoriler (arama destekli)
    if (_selectedIndex == 1) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        return Scaffold(
          appBar: _buildFavoritesAppBar(),
          body: const Center(child: Text('Giriş yapmalısınız.')),
          bottomNavigationBar: buildBottomNavBar(),
        );
      }

      return Scaffold(
        appBar: _buildFavoritesAppBar(),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('favorites')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return const Center(child: Text('Favori ürününüz yok.'));
            }

            final favProducts = docs
                .map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Product(
                    id: doc.id,
                    name: data['name'] ?? '',
                    price: (data['price'] ?? 0).toDouble(),
                    category: data['category'] ?? '',
                    description: data['description'] ?? '',
                    imageUrl: data['imageUrl'] ?? '',
                  );
                })
                .where(
                  _matchesFavoritesSearch,
                ) // Favoriler arama sorgusuna göre filtrele
                .toList();

            if (favProducts.isEmpty) {
              // Arama sorgusuna uygun favori yoksa
              return const Center(
                child: Text('Aramanıza uygun favori yok.'),
              ); // Favori ürün bulunamadı
            }

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemCount: favProducts.length,
              itemBuilder: (context, index) {
                final p = favProducts[index];
                final isFavorite = favoriteProductIds.contains(p.id);
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProductDetailPage(
                          product: p,
                          isFavorite: isFavorite,
                          onToggleFavorite: () {
                            final currentlyFavorite = favoriteProductIds
                                .contains(p.id);
                            setState(() {
                              if (currentlyFavorite) {
                                favoriteProductIds.remove(p.id);
                                removeFavorite(p.id);
                              } else {
                                favoriteProductIds.add(p.id);
                                addFavorite(p);
                              }
                            });
                          },
                          onAddToCart: () {
                            setState(() {
                              cart.add(p);
                            });
                            addToCart(p);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${p.name} sepete eklendi'),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                  child: Card(
                    elevation: 3,
                    shadowColor: const Color.fromARGB(255, 255, 228, 251),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: p.imageUrl.isNotEmpty
                              ? Image.network(
                                  p.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, _) =>
                                      Container(color: Colors.grey[200]),
                                )
                              : Container(color: Colors.grey[200]),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                '${p.price.toStringAsFixed(2)} ₺',
                                style: const TextStyle(
                                  color: Color.fromARGB(255, 255, 118, 221),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      isFavorite
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: isFavorite
                                          ? Colors.redAccent
                                          : Colors.grey,
                                    ),
                                    onPressed: () {
                                      final currentlyFavorite =
                                          favoriteProductIds.contains(p.id);
                                      setState(() {
                                        if (currentlyFavorite) {
                                          favoriteProductIds.remove(p.id);
                                          removeFavorite(p.id);
                                        } else {
                                          favoriteProductIds.add(p.id);
                                          addFavorite(p);
                                        }
                                      });
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.add_shopping_cart,
                                      color: Color.fromARGB(255, 255, 127, 240),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        cart.add(p);
                                      });
                                      addToCart(p);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${p.name} sepete eklendi',
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        bottomNavigationBar: buildBottomNavBar(),
      );
    }

    // Anasayfa (arama + kategori)
    final Map<String, IconData> categoryIcons = {
      'Tümü': Icons.storefront,
      'Elektronik': Icons.devices,
      'Ayakkabı': Icons.directions_walk,
      'Giyim': Icons.checkroom,
      'Kırtasiye': Icons.book,
      'Oyuncak': Icons.toys,
    };
    return Scaffold(
      appBar: _buildHomeAppBar(),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('products').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final products = snapshot.data!.docs
              .map((doc) => Product.fromFirestore(doc))
              .toList();
          final filteredProducts =
              products //sadece true dönen ürünler ekranda listelenir.
                  .where(_matchesSearch)
                  .toList(); // Arama sorgusuna göre filtrele

          final categories =
              products.map((p) => p.category.trim()).toSet().toList()
                ..sort(); // Kategorileri al ve sırala
          categories.insert(0, 'Tümü'); // Tüm kategoriyi ekle

          return ListView(
            children: [
              // --- Kategori Barı ---
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final isSelected = selectedCategory == category;
                    final iconData = categoryIcons[category] ?? Icons.category;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedCategory = category;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 80,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color.fromARGB(255, 255, 157, 189)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color.fromARGB(
                                255,
                                255,
                                0,
                                183,
                              ).withOpacity(0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                          border: Border.all(
                            color: isSelected
                                ? const Color.fromARGB(255, 255, 160, 231)
                                : Colors.orange.shade100,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              iconData,
                              size: 28,
                              color: isSelected
                                  ? Colors.white
                                  : const Color.fromARGB(255, 255, 171, 238),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              category,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : const Color.fromARGB(255, 255, 176, 255),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              // --- Banner/Slider Alanı ---
              SizedBox(
                height: 180,
                child: PageView(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        image: const DecorationImage(
                          image: AssetImage('assets/images/foto.png'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        image: const DecorationImage(
                          image: AssetImage('assets/images/foto2.png'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // --- Arama Sonuçları / Kategoriye Göre Ürünler ---
              if (filteredProducts.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(
                    child: Text(
                      'Aramanıza uygun ürün bulunamadı.',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                )
              else if (selectedCategory == 'Tümü')
                ...categories.where((cat) => cat != 'Tümü').map((category) {
                  // Kategorilere göre ürünleri listele
                  final categoryProducts =
                      filteredProducts // Kategoriye göre filtrele
                          .where(
                            (p) => p.category.trim() == category,
                          ) // Kategoriye göre filtrele
                          .toList(); // Kategoriye göre ürünleri al
                  if (categoryProducts.isEmpty)
                    return const SizedBox(); // Eğer kategoriye uygun ürün yoksa boş bir widget döndür

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          category,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 235, 169, 255),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 270,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: categoryProducts.length,
                          itemBuilder: (context, index) {
                            final p = categoryProducts[index];
                            final isFavorite = favoriteProductIds.contains(
                              p.id,
                            );
                            return Container(
                              width: 170,
                              margin: const EdgeInsets.only(left: 16, right: 8),
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ProductDetailPage(
                                        product: p,
                                        isFavorite: isFavorite,
                                        onToggleFavorite: () {
                                          final currentlyFavorite =
                                              favoriteProductIds.contains(p.id);
                                          setState(() {
                                            if (currentlyFavorite) {
                                              favoriteProductIds.remove(p.id);
                                              removeFavorite(p.id);
                                            } else {
                                              favoriteProductIds.add(p.id);
                                              addFavorite(p);
                                            }
                                          });
                                        },
                                        onAddToCart: () {
                                          setState(() {
                                            cart.add(p);
                                          });
                                          addToCart(p);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                '${p.name} sepete eklendi',
                                              ),
                                              duration: const Duration(
                                                seconds: 1,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                                child: Card(
                                  elevation: 3,
                                  shadowColor: const Color.fromARGB(
                                    255,
                                    255,
                                    228,
                                    251,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  clipBehavior: Clip.hardEdge,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: p.imageUrl.isNotEmpty
                                            ? Image.network(
                                                p.imageUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (context, error, _) =>
                                                        Container(
                                                          color:
                                                              Colors.grey[200],
                                                        ),
                                              )
                                            : Container(
                                                color: Colors.grey[200],
                                              ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            Text(
                                              '${p.price.toStringAsFixed(2)} ₺',
                                              style: const TextStyle(
                                                color: Color.fromARGB(
                                                  255,
                                                  255,
                                                  118,
                                                  221,
                                                ),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                IconButton(
                                                  icon: Icon(
                                                    isFavorite
                                                        ? Icons.favorite
                                                        : Icons.favorite_border,
                                                    color: isFavorite
                                                        ? Colors.redAccent
                                                        : Colors.grey,
                                                  ),
                                                  onPressed: () {
                                                    final currentlyFavorite =
                                                        favoriteProductIds
                                                            .contains(p.id);
                                                    setState(() {
                                                      if (currentlyFavorite) {
                                                        favoriteProductIds
                                                            .remove(p.id);
                                                        removeFavorite(p.id);
                                                      } else {
                                                        favoriteProductIds.add(
                                                          p.id,
                                                        );
                                                        addFavorite(p);
                                                      }
                                                    });
                                                  },
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.add_shopping_cart,
                                                    color: Color.fromARGB(
                                                      255,
                                                      255,
                                                      127,
                                                      240,
                                                    ),
                                                  ),
                                                  onPressed: () {
                                                    setState(() {
                                                      cart.add(p);
                                                    });
                                                    addToCart(p);
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          '${p.name} sepete eklendi',
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  );
                }).toList()
              else
                Builder(
                  builder: (context) {
                    final categoryProducts =
                        filteredProducts // Kategoriye göre filtrele
                            .where(
                              (p) => p.category.trim() == selectedCategory,
                            ) // Kategoriye göre filtrele
                            .toList(); // Kategoriye göre ürünleri al
                    if (categoryProducts.isEmpty) {
                      // Eğer kategoriye uygun ürün yoksa
                      return const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(
                          child: Text(
                            'Bu kategoride aramanıza uygun ürün yok.', // Eğer kategoriye uygun ürün yoksa bu yazıyı çıkart
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Text(
                            selectedCategory,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(255, 255, 0, 191),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 270,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: categoryProducts.length,
                            itemBuilder: (context, index) {
                              final p = categoryProducts[index];
                              final isFavorite = favoriteProductIds.contains(
                                p.id,
                              );
                              return Container(
                                width: 170,
                                margin: const EdgeInsets.only(
                                  left: 16,
                                  right: 8,
                                ),
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ProductDetailPage(
                                          product: p,
                                          isFavorite: isFavorite,
                                          onToggleFavorite: () {
                                            final currentlyFavorite =
                                                favoriteProductIds.contains(
                                                  p.id,
                                                );
                                            setState(() {
                                              if (currentlyFavorite) {
                                                favoriteProductIds.remove(p.id);
                                                removeFavorite(p.id);
                                              } else {
                                                favoriteProductIds.add(p.id);
                                                addFavorite(p);
                                              }
                                            });
                                          },
                                          onAddToCart: () {
                                            setState(() {
                                              cart.add(p);
                                            });
                                            addToCart(p);
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  '${p.name} sepete eklendi',
                                                ),
                                                duration: const Duration(
                                                  seconds: 1,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                  child: Card(
                                    elevation: 3,
                                    shadowColor: const Color.fromARGB(
                                      255,
                                      255,
                                      84,
                                      212,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    clipBehavior: Clip.hardEdge,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: p.imageUrl.isNotEmpty
                                              ? Image.network(
                                                  p.imageUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        _,
                                                      ) => Container(
                                                        color: Colors.grey[200],
                                                      ),
                                                )
                                              : Container(
                                                  color: Colors.grey[200],
                                                ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                p.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              Text(
                                                '${p.price.toStringAsFixed(2)} ₺',
                                                style: const TextStyle(
                                                  color: Color.fromARGB(
                                                    255,
                                                    255,
                                                    40,
                                                    201,
                                                  ),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  IconButton(
                                                    icon: Icon(
                                                      isFavorite
                                                          ? Icons.favorite
                                                          : Icons
                                                                .favorite_border,
                                                      color: isFavorite
                                                          ? Colors.redAccent
                                                          : Colors.grey,
                                                    ),
                                                    onPressed: () {
                                                      final currentlyFavorite =
                                                          favoriteProductIds
                                                              .contains(p.id);
                                                      setState(() {
                                                        if (currentlyFavorite) {
                                                          favoriteProductIds
                                                              .remove(p.id);
                                                          removeFavorite(p.id);
                                                        } else {
                                                          favoriteProductIds
                                                              .add(p.id);
                                                          addFavorite(p);
                                                        }
                                                      });
                                                    },
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.add_shopping_cart,
                                                      color: Color.fromARGB(
                                                        255,
                                                        255,
                                                        77,
                                                        187,
                                                      ),
                                                    ),
                                                    onPressed: () {
                                                      setState(() {
                                                        cart.add(p);
                                                      });
                                                      addToCart(p);
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            '${p.name} sepete eklendi',
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
      bottomNavigationBar: buildBottomNavBar(),
    );
  }

  BottomNavigationBar buildBottomNavBar() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      selectedItemColor: const Color.fromARGB(255, 245, 0, 184),
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      onTap: (index) {
        if (index == 2) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CartScreen(
                cart: cart,
                onRemove: (product) {
                  setState(() {
                    cart.remove(product);
                  });
                  removeFromCart(product.id);
                },
              ),
            ),
          );
          return;
        }

        setState(() {
          // Sekme değişince ilgili olmayan arama alanlarını temizle
          if (index != 0) {
            searchQuery = '';
            _searchController.clear();
            selectedCategory = 'Tümü';
          }
          if (index != 1) {
            favoritesSearchQuery = '';
            _favoritesSearchController.clear();
          }
          _selectedIndex = index;
        });
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Anasayfa'),
        BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favoriler'),
        BottomNavigationBarItem(
          icon: Icon(Icons.shopping_cart),
          label: 'Sepet',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long),
          label: 'Siparişlerim',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildProfileCard(List<Widget> children) {
    return Card(elevation: 2, child: Column(children: children));
  }

  Widget _buildProfileItem({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color.fromARGB(255, 255, 77, 222)),
      title: Text(title),
      subtitle: Text(value),
      trailing: const Icon(Icons.edit, color: Colors.grey),
      onTap: onTap,
    );
  }

  Future<void> _showEditDialog(String field, String hint) async {
    final controller = TextEditingController(text: userProfile[field] ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(hint),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.of(context).pop(controller.text.trim());
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (result != null) {
      final updatedProfile = Map<String, dynamic>.from(userProfile);
      updatedProfile[field] = result;
      await saveUserProfile(updatedProfile);
    }
  }
}

// --- CART SCREEN (Sahte Kart Ödemesi Entegre) ---

class CartScreen extends StatelessWidget {
  final List<Product> cart;
  final void Function(Product) onRemove;

  const CartScreen({super.key, required this.cart, required this.onRemove});

  Future<void> _startCheckout(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || cart.isEmpty) return;

    // Adres kontrolü
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final address = userDoc.data()?['address'];
    if (address == null || address.toString().trim().isEmpty) {
      // ignore: use_build_context_synchronously
      final shouldEdit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Adres Gerekli'),
          content: const Text(
            'Sipariş verebilmek için önce profilinizden adres eklemelisiniz.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Adresi Düzenle'),
            ),
          ],
        ),
      );
      if (shouldEdit == true) {
        Navigator.of(context).pop();
      }
      return;
    }

    final total = cart.fold(0.0, (sum, item) => sum + item.price);

    // Ödeme ekranına git (sahte kredi kartı)
    // ignore: use_build_context_synchronously
    final PaymentResult? result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FakePaymentScreen(totalAmount: total)),
    );

    if (result == null || result.success == false) {
      // Ödeme iptal/başarısız
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ödeme tamamlanamadı.')));
      return;
    }

    // Ödeme başarılı -> Siparişi oluştur
    // ignore: use_build_context_synchronously
    await _completeOrder(context, address: address.toString(), payment: result);
  }

  Future<void> _completeOrder(
    BuildContext context, {
    required String address,
    required PaymentResult payment,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || cart.isEmpty) return;

    final total = cart.fold(0.0, (sum, item) => sum + item.price);

    // Siparişi Firestore'a kaydet (ödeme bilgisi ile)
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('orders')
        .add({
          'createdAt': FieldValue.serverTimestamp(),
          'items': cart
              .map(
                (p) => {
                  'id': p.id,
                  'name': p.name,
                  'price': p.price,
                  'imageUrl': p.imageUrl,
                },
              )
              .toList(),
          'total': total,
          'address': address,
          'payment': payment.toMap(),
        });

    // Sepeti Firestore'dan temizle
    for (final p in cart) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('cart')
          .doc(p.id)
          .delete();
    }

    // Sepeti ekrandan da temizle
    for (final p in List<Product>.from(cart)) {
      onRemove(p);
    }

    // Bildirim
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ödeme alındı, siparişiniz oluşturuldu!')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final total = cart.fold(0.0, (sum, item) => sum + item.price);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sepetim'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
      ),
      body: cart.isEmpty
          ? const Center(child: Text('Sepetiniz boş.'))
          : ListView.builder(
              itemCount: cart.length,
              itemBuilder: (context, index) {
                final item = cart[index];
                return ListTile(
                  leading: Image.network(
                    item.imageUrl,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                  title: Text(item.name),
                  subtitle: Text('${item.price.toStringAsFixed(2)} ₺'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () {
                      onRemove(item);
                    },
                  ),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Toplam: ${total.toStringAsFixed(2)} ₺',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (cart.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.lock),
                  label: const Text("Ödemeye Geç"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 255, 71, 252),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  onPressed: () => _startCheckout(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- FAKE PAYMENT SCREEN (Sahte Kredi Kartı Ödemesi) ---

class FakePaymentScreen extends StatefulWidget {
  final double
  totalAmount; //totalAmount: Dışarıdan gelen ödenecek tutar (ör. sepet toplamı).
  const FakePaymentScreen({super.key, required this.totalAmount});

  @override
  State<FakePaymentScreen> createState() => _FakePaymentScreenState();
}

class _FakePaymentScreenState extends State<FakePaymentScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController cardNumberController = TextEditingController();
  final TextEditingController expiryController =
      TextEditingController(); // MM/YY
  final TextEditingController cvvController =
      TextEditingController(); //TextEditingController ile kullanıcıdan alınan inputları kontrol ediyoruz.

  bool isProcessing = false;
  String? errorText;

  @override
  void dispose() {
    nameController.dispose();
    cardNumberController.dispose();
    expiryController.dispose();
    cvvController.dispose();
    super.dispose();
  }

  String _detectBrand(String digitsOnly) {
    //Kart numarasına bakarak Visa, Mastercard, American Express gibi marka belirliyor.
    if (digitsOnly.startsWith('4')) return 'Visa';
    if (RegExp(r'^(5[1-5])').hasMatch(digitsOnly)) return 'Mastercard';
    if (RegExp(
      r'^(222[1-9]|22[3-9]\d|2[3-6]\d{2}|27[01]\d|2720)',
    ).hasMatch(digitsOnly))
      return 'Mastercard';
    if (digitsOnly.startsWith('34') || digitsOnly.startsWith('37'))
      return 'American Express';
    return 'Card';
  }

  bool _luhnValid(String number) {
    //Kart numaralarının gerçek olup olmadığını kontrol etmek için kullanılan klasik algoritma.
    final digits = number.replaceAll(' ', '');
    if (!RegExp(r'^\d{13,19}$').hasMatch(digits)) return false;
    int sum = 0;
    bool alternate = false;
    for (int i = digits.length - 1; i >= 0; i--) {
      int n = int.parse(digits[i]);
      if (alternate) {
        n *=
            2; //Her rakamı sondan başa doğru topluyor, bazılarını 2 ile çarpıp 9’dan büyükse çıkarıyor.
        if (n > 9) n -= 9;
      }
      sum += n;
      alternate = !alternate;
    }
    return sum % 10 ==
        0; //Sonuç 10’a tam bölünüyorsa kart numarası geçerli sayılıyor.
  }

  bool _expiryValid(String input) {
    //Regex ile ay (01–12) ve yıl (00–99) alınıyor.
    final match = RegExp(
      r'^\s*(0[1-9]|1[0-2])\s*/\s*([0-9]{2})\s*$',
    ).firstMatch(input);
    if (match == null) return false;
    final month = int.parse(match.group(1)!);
    final year = 2000 + int.parse(match.group(2)!);
    final now = DateTime.now();
    if (year > now.year) return true;
    if (year == now.year && month >= now.month)
      return true; //Şu anki tarih ile karşılaştırılıyor → geçmiş tarihse geçersiz.
    return false;
  }

  bool _cvvValid(String input, String brand) {
    final trimmed = input.trim();
    if (!RegExp(r'^\d{3,4}$').hasMatch(trimmed))
      return false; //CVV 3 veya 4 rakam olmalı.
    if (brand == 'American Express')
      return trimmed.length ==
          4; //American Express → 4 haneli, diğer kartlar → 3 haneli.
    return trimmed.length == 3;
  }

  Future<void> _pay() async {
    setState(() {
      errorText = null; //İlk olarak hatalar sıfırlanıyor.
    });

    final name = nameController.text
        .trim(); //Formdaki her alan tek tek kontrol ediliyor isim vesaire
    final number = cardNumberController.text.replaceAll(' ', '');
    final expiry = expiryController.text.trim();
    final cvv = cvvController.text.trim();
    final brand = _detectBrand(number);

    if (name.isEmpty) {
      setState(() => errorText = 'Kart üzerindeki adı giriniz.');
      return;
    }
    if (!_luhnValid(number)) {
      setState(() => errorText = 'Geçersiz kart numarası.');
      return;
    }
    if (!_expiryValid(expiry)) {
      setState(() => errorText = 'Geçersiz son kullanma tarihi (MM/YY).');
      return;
    }
    if (!_cvvValid(cvv, brand)) {
      setState(() => errorText = 'Geçersiz CVV.');
      return;
    }

    setState(() {
      isProcessing = true; //eğer hepsi doğruysa
    });

    // 2 saniye  Sahte ağ gecikmesi / işlem
    await Future.delayed(const Duration(seconds: 2));

    final last4 = number.substring(number.length - 4);
    final result = PaymentResult(
      //PaymentResult ile başarılı işlem dönüyor.
      success: true,
      method: 'card',
      brand: brand,
      last4: last4,
      paidAt: DateTime.now(),
    );

    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ödeme'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Ödenecek Tutar',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${widget.totalAmount.toStringAsFixed(2)} ₺',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Kart Üzerindeki İsim',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: cardNumberController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Kart Numarası',
              hintText: '4242 4242 4242 4242',
              prefixIcon: Icon(Icons.credit_card),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: expiryController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Son Kullanma (MM/YY)',
                    hintText: '12/28',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: cvvController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'CVV',
                    hintText: '123',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (errorText != null)
            Text(errorText!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: isProcessing ? null : _pay,
            icon: isProcessing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.lock),
            label: Text(
              isProcessing ? 'İşlem Yapılıyor...' : 'Ödemeyi Tamamla',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Not: Bu ekran demo amaçlıdır. Girdiğiniz veriler gerçek bir ödeme işlemi yapmaz.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// --- ORDERS SCREEN ---

class OrdersScreen extends StatelessWidget {
  final VoidCallback? onBack;
  const OrdersScreen({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Giriş yapmalısınız.')));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Siparişlerim'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
        leading: onBack != null
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack)
            : null,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('orders')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snapshot.data!.docs;
          if (orders.isEmpty) {
            return const Center(child: Text('Henüz siparişiniz yok.'));
          }
          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index].data() as Map<String, dynamic>;
              final items = (order['items'] as List<dynamic>);
              final total = (order['total'] ?? 0).toDouble();
              final date = (order['createdAt'] as Timestamp?)?.toDate();
              final payment = order['payment'] as Map<String, dynamic>?;

              final paymentSummary = payment == null
                  ? 'Ödeme: -'
                  : 'Ödeme: ${payment['status'] == 'paid' ? 'Ödendi' : 'Durum: ${payment['status']}'}'
                        ' - ${payment['brand'] ?? ''} **** ${payment['last4'] ?? ''}';

              return Card(
                margin: const EdgeInsets.all(12),
                child: ListTile(
                  title: Text(
                    'Sipariş #${orders[index].id.substring(0, 6)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (order['address'] != null)
                        Text(
                          'Adres: ${order['address']}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      if (date != null)
                        Text(
                          'Tarih: ${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      Text(
                        paymentSummary,
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      ...items.map(
                        (item) => Text(
                          '${item['name']} - ${item['price'].toStringAsFixed(2)} ₺',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Text(
                        'Toplam: ${total.toStringAsFixed(2)} ₺',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'Siparişi Sil',
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Siparişi Sil'),
                          content: const Text(
                            'Bu siparişi silmek istediğinize emin misiniz?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('İptal'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Sil'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .collection('orders')
                            .doc(orders[index].id)
                            .delete();
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sipariş silindi')),
                        );
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// --- REGISTER SCREEN ---
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String error = '';
  bool isLoading = false;

  Future<void> register() async {
    setState(() {
      isLoading = true;
      error = '';
    });

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      // ignore: use_build_context_synchronously
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() => error = e.message ?? 'Kayıt hatası');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kayıt Ol")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: "E-posta"),
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Şifre"),
            ),
            const SizedBox(height: 16),
            if (error.isNotEmpty)
              Text(error, style: const TextStyle(color: Colors.red)),
            ElevatedButton(
              onPressed: isLoading ? null : register,
              child: isLoading
                  ? const CircularProgressIndicator()
                  : const Text("Kayıt Ol"),
            ),
          ],
        ),
      ),
    );
  }
}

// --- PRODUCT DETAIL PAGE ---
class ProductDetailPage extends StatefulWidget {
  final Product product;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onAddToCart;

  const ProductDetailPage({
    super.key,
    required this.product,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onAddToCart,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late bool _localIsFavorite;

  @override
  void initState() {
    super.initState();
    _localIsFavorite = widget.isFavorite;
  }

  void _handleFavoritePressed() {
    setState(() {
      _localIsFavorite = !_localIsFavorite;
    });
    widget.onToggleFavorite();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _localIsFavorite ? Icons.favorite : Icons.favorite_border,
              color: _localIsFavorite ? Colors.red : Colors.grey,
            ),
            onPressed: _handleFavoritePressed,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: product.imageUrl.isNotEmpty
                  ? Image.network(
                      product.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, _) =>
                          Container(color: Colors.grey[200]),
                    )
                  : Container(color: Colors.grey[200]),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${product.price.toStringAsFixed(2)} ₺',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Color.fromARGB(255, 255, 0, 174),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    product.description,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: widget.onAddToCart,
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text("Sepete Ekle"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 255, 73, 179),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- LOGIN SCREEN ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String error = '';
  bool isLoading = false;

  Future<void> login() async {
    setState(() {
      isLoading = true;
      error = '';
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => error = e.message ?? 'Giriş hatası');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Giriş Yap")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: "E-posta"),
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Şifre"),
            ),
            const SizedBox(height: 16),
            if (error.isNotEmpty)
              Text(error, style: const TextStyle(color: Colors.red)),
            ElevatedButton(
              onPressed: isLoading ? null : login,
              child: isLoading
                  ? const CircularProgressIndicator()
                  : const Text("Giriş Yap"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                );
              },
              child: const Text("Hesabınız yok mu? Kayıt Ol"),
            ),
          ],
        ),
      ),
    );
  }
}
