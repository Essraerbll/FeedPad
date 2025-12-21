import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class MarkerDetailScreen extends StatefulWidget {
  final String markerId;
  final Map<String, dynamic> markerData;

  const MarkerDetailScreen({
    super.key,
    required this.markerId,
    required this.markerData,
  });

  @override
  State<MarkerDetailScreen> createState() => _MarkerDetailScreenState();
}

class _MarkerDetailScreenState extends State<MarkerDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  String? _userOpinion; // 'yes', 'maybe', or 'no'
  String? _wouldLikeToAdd; // 'yes' or 'no' (sadece Maybe/No seçildiğinde)
  final TextEditingController _addedAmountController = TextEditingController();
  String? _isEnoughNow; // 'yes' or 'maybe' (sadece ekleme yapıldığında)
  bool _isLoading = false;
  String? _username;
  String? _addedByUsername; // Son ekleme yapan kişinin kullanıcı adı
  bool _isLoadingUser = true;
  bool _isLoadingAddedBy = true;
  
  // Marker verilerini state'te tut (güncel veriler için)
  Map<String, dynamic> _currentMarkerData = {};

  @override
  void initState() {
    super.initState();
    _loadMarkerData(); // Backend'den güncel marker verilerini yükle
  }

  Future<void> _loadMarkerData() async {
    try {
      // Backend'den güncel marker verilerini al
      final markerResponse = await _apiService.getMarker(widget.markerId);
      if (markerResponse['success'] == true && markerResponse['marker'] != null) {
        final marker = markerResponse['marker'] as Map<String, dynamic>;
        
        // Marker verilerini state'te güncelle
        setState(() {
          _currentMarkerData = {
            ...widget.markerData,
            'addedAmount': marker['addedAmount'],
            'addedByUserId': marker['addedByUserId'],
            'isEnoughNow': marker['isEnoughNow'],
            'isWaterEnough': marker['isWaterEnough'],
          };
        });
        
        // Eğer marker'da addedAmount varsa, input'a yaz
        final addedAmount = marker['addedAmount'];
        if (addedAmount != null) {
          _addedAmountController.text = addedAmount.toString();
        }
        
        // Kullanıcı bilgilerini yükle
        final hasAddedBy = marker['addedByUserId'] != null;
        if (hasAddedBy) {
          _loadAddedByUserInfo();
        } else {
          _loadUserInfo(); // İlk ekleyen kişi için
        }
      } else {
        // Backend'den veri alınamazsa widget.markerData'dan yükle
        setState(() {
          _currentMarkerData = Map<String, dynamic>.from(widget.markerData);
        });
        _loadUserInfo();
        _loadAddedByUserInfo();
      }
    } catch (e) {
      print('Marker data loading error: $e');
      // Hata olsa bile kullanıcı bilgilerini yüklemeyi dene
      setState(() {
        _currentMarkerData = Map<String, dynamic>.from(widget.markerData);
      });
      _loadUserInfo();
      _loadAddedByUserInfo();
    }
  }

  @override
  void dispose() {
    _addedAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadAddedByUserInfo() async {
    try {
      // _currentMarkerData'dan kontrol et, yoksa widget.markerData'dan
      String? addedByUserId = _currentMarkerData['addedByUserId'] as String? ?? 
                              widget.markerData['addedByUserId'] as String?;
      
      if (addedByUserId != null) {
        final userResponse = await _apiService.get('/auth/user/$addedByUserId');
        if (userResponse['success'] == true && userResponse['user'] != null) {
          final user = userResponse['user'] as Map<String, dynamic>;
          setState(() {
            _addedByUsername = user['username'] as String? ??
                user['name'] as String? ??
                'Unknown';
            _isLoadingAddedBy = false;
          });
        } else {
          setState(() {
            _addedByUsername = 'Unknown';
            _isLoadingAddedBy = false;
          });
        }
      } else {
        setState(() {
          _addedByUsername = null;
          _isLoadingAddedBy = false;
        });
      }
    } catch (e) {
      print('Added by user info loading error: $e');
      setState(() {
        _addedByUsername = null;
        _isLoadingAddedBy = false;
      });
    }
  }

  Future<void> _loadUserInfo() async {
    try {
      // Önce marker verisinden userId'yi al, yoksa backend'den çek
      String? userId = widget.markerData['userId'] as String?;
      print('Marker data userId: $userId');

      // Eğer marker verisinde userId yoksa backend'den marker'ı çek
      if (userId == null) {
        print('UserId not found in marker data, fetching from backend...');
        final markerResponse = await _apiService.getMarker(widget.markerId);
        print('Marker response: $markerResponse');
        if (markerResponse['success'] == true &&
            markerResponse['marker'] != null) {
          final marker = markerResponse['marker'] as Map<String, dynamic>;
          userId = marker['userId'] as String?;
          print('UserId from backend: $userId');
        }
      }

      if (userId != null) {
        print('Fetching user info for userId: $userId');
        // Kullanıcı bilgilerini al
        final userResponse = await _apiService.get('/auth/user/$userId');
        print('User response: $userResponse');
        if (userResponse['success'] == true && userResponse['user'] != null) {
          final user = userResponse['user'] as Map<String, dynamic>;
          print('User data: $user');
          setState(() {
            _username = user['username'] as String? ??
                user['name'] as String? ??
                'Unknown';
            _isLoadingUser = false;
          });
          print('Username set to: $_username');
        } else {
          print('User response failed or user is null');
          setState(() {
            _username = 'Unknown';
            _isLoadingUser = false;
          });
        }
      } else {
        print('UserId is null');
        setState(() {
          _username = 'Unknown';
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      print('User info loading error: $e');
      setState(() {
        _username = 'Unknown';
        _isLoadingUser = false;
      });
    }
  }

  Future<void> _submitOpinion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // _currentMarkerData varsa onu kullan, yoksa widget.markerData'yı kullan
      final markerData = _currentMarkerData.isNotEmpty ? _currentMarkerData : widget.markerData;
      
      final markerType = markerData['type'] as String? ?? '';
      final currentIsEnough = markerData['isWaterEnough'] as String?;
      
      // Marker'ın mevcut rengini kontrol et
      Color currentColor;
      if (markerType == 'food' && markerData['petType'] != null) {
        currentColor = currentIsEnough == 'yes' 
            ? Colors.green 
            : currentIsEnough == 'maybe' 
                ? Colors.orange 
                : Colors.red;
      } else if (markerType == 'water') {
        currentColor = currentIsEnough == 'yes' 
            ? Colors.green 
            : currentIsEnough == 'maybe' 
                ? Colors.orange 
                : Colors.red;
      } else {
        currentColor = Colors.orange;
      }
      
      String? newIsEnough;
      double? addedAmount;
      String? addedByUserId;
      String? isEnoughNow;
      
      // Mevcut kullanıcı bilgisini al
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;
      
      if (_userOpinion == 'yes') {
        // Yes seçildi: Marker'ın arka planı turuncu/kırmızıysa yeşile çevir
        if (currentColor == Colors.orange || currentColor == Colors.red) {
          newIsEnough = 'yes';
        } else {
          // Zaten yeşilse değişiklik yok
          newIsEnough = currentIsEnough;
        }
      } else if (_userOpinion == 'maybe' || _userOpinion == 'no') {
        // Maybe veya No seçildi: "Would you like to add?" sorusuna göre
        if (_wouldLikeToAdd == 'yes') {
          // Yes seçildi: Eklenen miktarı ve yeterlilik durumunu kaydet
          if (_addedAmountController.text.isNotEmpty) {
            addedAmount = double.tryParse(_addedAmountController.text);
            if (addedAmount == null || addedAmount <= 0) {
              throw Exception('Please enter a valid positive number');
            }
            addedByUserId = currentUser?.id;
            isEnoughNow = _isEnoughNow;
            
            // isEnoughNow'e göre marker rengini güncelle
            if (isEnoughNow == 'yes') {
              newIsEnough = 'yes'; // Yeşil
            } else if (isEnoughNow == 'maybe') {
              newIsEnough = 'maybe'; // Turuncu
            } else {
              newIsEnough = currentIsEnough;
            }
          } else {
            throw Exception('Please enter the amount you added');
          }
        } else if (_wouldLikeToAdd == 'no') {
          // No seçildi: Marker'ı "Is food/water enough?" sorusuna verilen cevaba göre güncelle
          newIsEnough = _userOpinion; // 'maybe' → turuncu, 'no' → kırmızı, 'yes' → yeşil
        } else {
          newIsEnough = currentIsEnough;
        }
      } else {
        newIsEnough = currentIsEnough;
      }
      
      // Backend'e marker'ı güncelle
      final updateResponse = await _apiService.updateMarker(
        widget.markerId,
        isWaterEnough: newIsEnough,
        addedAmount: addedAmount,
        addedByUserId: addedByUserId,
        isEnoughNow: isEnoughNow,
      );
      
      // Güncellenmiş marker verilerini al
      final updatedMarker = updateResponse['marker'] as Map<String, dynamic>?;
      
      // Eğer ekleme yapıldıysa, marker verilerini ve kullanıcı bilgilerini yeniden yükle
      if (addedByUserId != null && mounted) {
        // Marker verilerini state'te güncelle
        setState(() {
          _currentMarkerData['addedAmount'] = updatedMarker?['addedAmount'] ?? addedAmount;
          _currentMarkerData['addedByUserId'] = updatedMarker?['addedByUserId'] ?? addedByUserId;
          _currentMarkerData['isEnoughNow'] = updatedMarker?['isEnoughNow'] ?? isEnoughNow;
          _currentMarkerData['isWaterEnough'] = updatedMarker?['isWaterEnough'] ?? newIsEnough;
        });
        
        // Kullanıcı bilgilerini yeniden yükle
        await _loadAddedByUserInfo();
      }
      
      // Popup'ı kapat ve callback ile marker'ı güncelle
      if (mounted) {
        Navigator.pop(context, {
          'markerId': widget.markerId,
          'isWaterEnough': updatedMarker?['isWaterEnough'] ?? newIsEnough,
          'addedAmount': updatedMarker?['addedAmount'] ?? addedAmount,
          'addedByUserId': updatedMarker?['addedByUserId'] ?? addedByUserId,
          'isEnoughNow': updatedMarker?['isEnoughNow'] ?? isEnoughNow,
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Opinion submitted successfully',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'An error occurred: $e',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // _currentMarkerData varsa onu kullan, yoksa widget.markerData'yı kullan
    final markerData = _currentMarkerData.isNotEmpty ? _currentMarkerData : widget.markerData;
    
    final markerType = markerData['type'] as String? ?? '';
    final petType = markerData['petType'] as String?;
    final waterLiters = markerData['waterLiters'] as double?;
    final isWaterEnough = markerData['isWaterEnough'] as String?;
    final hasAddedBy = markerData['addedByUserId'] != null;
    final addedAmount = markerData['addedAmount'];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.purple[900],
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Başlık
                Text(
                  'Marker Details',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Form alanları ve butonlar için beyaz çerçeve
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Last added by (eğer ekleme yapılmışsa) veya Added by (eğer ekleme yapılmamışsa)
                      if (hasAddedBy)
                        // Son ekleme yapan kişi
                        _isLoadingAddedBy
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.all(12.0),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.person_add, color: Colors.grey, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Last added by',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 10,
                                            ),
                                          ),
                                          Text(
                                            _addedByUsername ?? 'Unknown',
                                            style: const TextStyle(
                                              color: Colors.black87,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                      else
                        // İlk ekleyen kişi
                        _isLoadingUser
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.all(12.0),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.person, color: Colors.grey, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Added by',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 10,
                                            ),
                                          ),
                                          Text(
                                            _username ?? 'Unknown',
                                            style: const TextStyle(
                                              color: Colors.black87,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      const SizedBox(height: 16),

                      // Marker bilgileri
                      _buildInfoRow(
                        'Type',
                        markerType == 'food' ? 'Food' : 'Water',
                        Icons.category,
                      ),
                      const SizedBox(height: 12),

                      if (petType != null)
                        _buildInfoRow(
                          'Pet Type',
                          petType == 'cat' ? 'Cat' : 'Dog',
                          Icons.pets,
                        ),
                      if (petType != null) const SizedBox(height: 12),

                      // Eğer ekleme yapılmışsa son eklenen miktarı göster, yoksa ilk miktarı göster
                      if (hasAddedBy && addedAmount != null)
                        // Son eklenen miktar
                        _buildInfoRow(
                          markerType == 'water'
                              ? 'Last added water'
                              : 'Last added food',
                          '${(addedAmount as num).toStringAsFixed(1)} ${markerType == 'water' ? 'liters' : 'kilograms'}',
                          markerType == 'water'
                              ? Icons.add_circle
                              : Icons.add_circle,
                        )
                      else if (waterLiters != null)
                        // İlk miktar
                        _buildInfoRow(
                          markerType == 'water'
                              ? 'Water Amount'
                              : 'Food Amount',
                          '${waterLiters.toStringAsFixed(1)} ${markerType == 'water' ? 'liters' : 'kilograms'}',
                          markerType == 'water'
                              ? Icons.water_drop
                              : Icons.restaurant,
                        ),
                      if ((hasAddedBy && addedAmount != null) || waterLiters != null)
                        const SizedBox(height: 12),

                      if (isWaterEnough != null)
                        _buildInfoRow(
                          markerType == 'water'
                              ? 'Is Water Enough?'
                              : 'Is Food Enough?',
                          isWaterEnough == 'yes'
                              ? 'Yes'
                              : isWaterEnough == 'maybe'
                                  ? 'Maybe'
                                  : 'No',
                          Icons.check_circle,
                        ),
                      if (isWaterEnough != null) const SizedBox(height: 20),

                      // Ayırıcı
                      const Divider(
                        thickness: 1,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your Opinion',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),

                      // Opinion sorusu
                      Text(
                        markerType == 'water'
                            ? 'Is Water Enough?'
                            : 'Is Food Enough?',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _userOpinion,
                        style: const TextStyle(color: Colors.black87),
                        dropdownColor: Colors.white,
                        decoration: InputDecoration(
                          labelText: 'Select an option',
                          labelStyle: const TextStyle(color: Colors.grey),
                          prefixIcon:
                              const Icon(Icons.rate_review, color: Colors.grey),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.grey),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Colors.purple, width: 2),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem<String>(
                            value: 'yes',
                            child: Text('Yes'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'maybe',
                            child: Text('Maybe'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'no',
                            child: Text('No'),
                          ),
                        ],
                        onChanged: (String? value) {
                          setState(() {
                            _userOpinion = value;
                            // Maybe veya No seçilmediyse wouldLikeToAdd'ı sıfırla
                            if (value != 'maybe' && value != 'no') {
                              _wouldLikeToAdd = null;
                            }
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select an option';
                          }
                          return null;
                        },
                      ),
                      // "Would you like to add?" sorusu (sadece Maybe veya No seçildiğinde)
                      if (_userOpinion == 'maybe' || _userOpinion == 'no') ...[
                        const SizedBox(height: 16),
                        Text(
                          'Would you like to add?',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _wouldLikeToAdd,
                          style: const TextStyle(color: Colors.black87),
                          dropdownColor: Colors.white,
                          decoration: InputDecoration(
                            labelText: 'Select an option',
                            labelStyle: const TextStyle(color: Colors.grey),
                            prefixIcon: const Icon(Icons.add_circle,
                                color: Colors.grey),
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Colors.purple, width: 2),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem<String>(
                              value: 'yes',
                              child: Text('Yes'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'no',
                              child: Text('No'),
                            ),
                          ],
                          onChanged: (String? value) {
                            setState(() {
                              _wouldLikeToAdd = value;
                              // No seçilirse ekleme alanlarını sıfırla
                              if (value == 'no') {
                                _addedAmountController.clear();
                                _isEnoughNow = null;
                              }
                            });
                          },
                          validator: (value) {
                            if ((_userOpinion == 'maybe' || _userOpinion == 'no') &&
                                (value == null || value.isEmpty)) {
                              return 'Please select an option';
                            }
                            return null;
                          },
                        ),
                        // "Would you like to add?" sorusuna "Yes" denirse gösterilecek alanlar
                        if (_wouldLikeToAdd == 'yes') ...[
                          const SizedBox(height: 16),
                          Text(
                            markerType == 'water'
                                ? 'How many liters of water did you add?'
                                : 'How many kilograms of food did you add?',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _addedAmountController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            style: const TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              labelText: 'Enter amount',
                              labelStyle: const TextStyle(color: Colors.grey),
                              prefixIcon: Icon(
                                markerType == 'water'
                                    ? Icons.water_drop
                                    : Icons.restaurant,
                                color: Colors.grey,
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Colors.purple, width: 2),
                              ),
                            ),
                            validator: (value) {
                              if (_wouldLikeToAdd == 'yes' &&
                                  (value == null || value.isEmpty)) {
                                return markerType == 'water'
                                    ? 'Please enter the amount of water'
                                    : 'Please enter the amount of food';
                              }
                              if (value != null && value.isNotEmpty) {
                                final parsed = double.tryParse(value);
                                if (parsed == null || parsed <= 0) {
                                  return 'Please enter a valid positive number';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Text(
                            markerType == 'water'
                                ? 'Is there enough water now?'
                                : 'Is there enough food now?',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _isEnoughNow,
                            style: const TextStyle(color: Colors.black87),
                            dropdownColor: Colors.white,
                            decoration: InputDecoration(
                              labelText: 'Select an option',
                              labelStyle: const TextStyle(color: Colors.grey),
                              prefixIcon: const Icon(Icons.check_circle,
                                  color: Colors.grey),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Colors.purple, width: 2),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem<String>(
                                value: 'yes',
                                child: Text('Yes'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'maybe',
                                child: Text('Maybe'),
                              ),
                            ],
                            onChanged: (String? value) {
                              setState(() {
                                _isEnoughNow = value;
                              });
                            },
                            validator: (value) {
                              if (_wouldLikeToAdd == 'yes' &&
                                  (value == null || value.isEmpty)) {
                                return 'Please select an option';
                              }
                              return null;
                            },
                          ),
                        ],
                      ],
                      const SizedBox(height: 24),

                      // Submit butonu
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submitOpinion,
                        style: ButtonStyle(
                          backgroundColor:
                              MaterialStateProperty.all(Colors.blue),
                          foregroundColor:
                              MaterialStateProperty.all(Colors.white),
                          side: MaterialStateProperty.all(
                            BorderSide(color: Colors.blue, width: 2),
                          ),
                          padding: MaterialStateProperty.all(
                            const EdgeInsets.symmetric(
                                vertical: 20, horizontal: 24),
                          ),
                          minimumSize: MaterialStateProperty.all(
                            const Size(double.infinity, 56),
                          ),
                          shape: MaterialStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Submit Opinion',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                      const SizedBox(height: 16),

                      // Cancel butonu
                      OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: ButtonStyle(
                          backgroundColor:
                              MaterialStateProperty.all(Colors.red),
                          foregroundColor:
                              MaterialStateProperty.all(Colors.white),
                          side: MaterialStateProperty.all(
                            BorderSide(color: Colors.red, width: 2),
                          ),
                          padding: MaterialStateProperty.all(
                            const EdgeInsets.symmetric(
                                vertical: 20, horizontal: 24),
                          ),
                          minimumSize: MaterialStateProperty.all(
                            const Size(double.infinity, 56),
                          ),
                          shape: MaterialStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
