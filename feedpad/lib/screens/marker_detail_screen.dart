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
  String? _userOpinion;
  String? _wouldLikeToAdd;
  final TextEditingController _addedAmountController = TextEditingController();
  String? _isEnoughNow;
  String?
      _wouldLikeToDonate;
  String? _donatePetType;
  final TextEditingController _donateKilosController = TextEditingController();
  bool _isLoading = false;
  String? _username;
  String? _addedByUsername;
  bool _isLoadingUser = true;
  bool _isLoadingAddedBy = true;

  Map<String, dynamic> _currentMarkerData = {};

  @override
  void initState() {
    super.initState();
    _currentMarkerData = Map<String, dynamic>.from(widget.markerData);
    _loadMarkerData();
  }

  Future<void> _loadMarkerData() async {
    try {
      final markerResponse = await _apiService.getMarker(widget.markerId);
      if (markerResponse['success'] == true &&
          markerResponse['marker'] != null) {
        final marker = markerResponse['marker'] as Map<String, dynamic>;

        setState(() {
          _currentMarkerData = {
            'id': marker['id'] ?? widget.markerData['id'],
            'userId': marker['userId'] ?? widget.markerData['userId'],
            'userType': widget
                .markerData['userType'],
            'type': marker['type'] ?? widget.markerData['type'],
            'latitude': marker['latitude'] ?? widget.markerData['latitude'],
            'longitude': marker['longitude'] ?? widget.markerData['longitude'],
            'addedAmount': marker['addedAmount'] ?? null,
            'addedByUserId': marker['addedByUserId'] ?? null,
            'isEnoughNow': marker['isEnoughNow'] ?? null,
            'isWaterEnough': marker['isWaterEnough'] ?? null,
            'waterLiters': marker['waterLiters'] != null
                ? ((marker['waterLiters'] is int)
                    ? (marker['waterLiters'] as int).toDouble()
                    : (marker['waterLiters'] as num).toDouble())
                : null,
            'petType': marker['petType'] ?? null,
            'catFoodAmount': marker['catFoodAmount'] != null
                ? ((marker['catFoodAmount'] is int)
                    ? (marker['catFoodAmount'] as int).toDouble()
                    : (marker['catFoodAmount'] as num).toDouble())
                : null,
            'dogFoodAmount': marker['dogFoodAmount'] != null
                ? ((marker['dogFoodAmount'] is int)
                    ? (marker['dogFoodAmount'] as int).toDouble()
                    : (marker['dogFoodAmount'] as num).toDouble())
                : null,
          };
        });

        if (marker['catFoodAmount'] != null ||
            marker['dogFoodAmount'] != null) {
          _wouldLikeToDonate = 'yes';
          if (marker['catFoodAmount'] != null) {
            _donatePetType = 'cat';
            _donateKilosController.text = marker['catFoodAmount'].toString();
          } else if (marker['dogFoodAmount'] != null) {
            _donatePetType = 'dog';
            _donateKilosController.text = marker['dogFoodAmount'].toString();
          }
        } else {
          _wouldLikeToDonate = null;
          _donatePetType = null;
          _donateKilosController.clear();
        }

        final addedAmount = marker['addedAmount'];
        if (addedAmount != null) {
          _addedAmountController.text = addedAmount.toString();
        }

        final hasAddedBy = marker['addedByUserId'] != null;
        if (hasAddedBy) {
          _loadAddedByUserInfo();
        } else {
          _loadUserInfo();
        }
      } else {
        setState(() {
          _currentMarkerData = Map<String, dynamic>.from(widget.markerData);
        });
        _loadUserInfo();
        _loadAddedByUserInfo();
      }
    } catch (e) {
      print('Marker data loading error: $e');
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
    _donateKilosController.dispose();
    super.dispose();
  }

  Future<void> _loadAddedByUserInfo() async {
    try {
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
      String? userId = widget.markerData['userId'] as String?;
      print('Marker data userId: $userId');

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
      final markerData = _currentMarkerData.isNotEmpty
          ? _currentMarkerData
          : widget.markerData;

      final markerType = markerData['type'] as String? ?? '';
      final currentIsEnough = markerData['isWaterEnough'] as String?;

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

      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;
      final isPetShopOwner = currentUser?.userType == 'pet_shop_owner';
      final markerUserId = markerData['userId'] as String?;
      final markerUserType = markerData['userType'] as String?;
      final isMarkerOwnerPetShopOwner = markerUserType == 'pet_shop_owner';
      final isCurrentUserMarkerOwner = currentUser?.id == markerUserId;
      final shouldShowDonateQuestion =
          isMarkerOwnerPetShopOwner && isCurrentUserMarkerOwner;

      double? newCatFoodAmount;
      double? newDogFoodAmount;

      final currentCatFoodAmount = markerData['catFoodAmount'] != null
          ? ((markerData['catFoodAmount'] is int)
              ? (markerData['catFoodAmount'] as int).toDouble()
              : (markerData['catFoodAmount'] as num).toDouble())
          : null;
      final currentDogFoodAmount = markerData['dogFoodAmount'] != null
          ? ((markerData['dogFoodAmount'] is int)
              ? (markerData['dogFoodAmount'] as int).toDouble()
              : (markerData['dogFoodAmount'] as num).toDouble())
          : null;

      if (shouldShowDonateQuestion) {
        if (_wouldLikeToDonate == 'yes') {
          newIsEnough = 'yes';
          if (_donateKilosController.text.isNotEmpty &&
              _donatePetType != null) {
            final donateKilosAmount =
                double.tryParse(_donateKilosController.text);

            if (_donatePetType == 'cat') {
              newCatFoodAmount = donateKilosAmount;
              newDogFoodAmount = currentDogFoodAmount;
            } else if (_donatePetType == 'dog') {
              newCatFoodAmount = currentCatFoodAmount;
              newDogFoodAmount = donateKilosAmount;
            }
          }
        } else if (_wouldLikeToDonate == 'no') {
          newIsEnough = 'no';
          newCatFoodAmount = null;
          newDogFoodAmount = null;
        } else {
          newIsEnough = currentIsEnough;
          newCatFoodAmount = currentCatFoodAmount;
          newDogFoodAmount = currentDogFoodAmount;
        }
      } else if (isPetShopOwner && !shouldShowDonateQuestion) {
        newIsEnough = currentIsEnough;
      } else if (_userOpinion == 'yes') {
        if (currentColor == Colors.orange || currentColor == Colors.red) {
          newIsEnough = 'yes';
        } else {
          newIsEnough = currentIsEnough;
        }
      } else if (_userOpinion == 'maybe' || _userOpinion == 'no') {
        if (_wouldLikeToAdd == 'yes') {
          if (_addedAmountController.text.isNotEmpty) {
            addedAmount = double.tryParse(_addedAmountController.text);
            if (addedAmount == null || addedAmount <= 0) {
              throw Exception('Please enter a valid positive number');
            }
            addedByUserId = currentUser?.id;
            isEnoughNow = _isEnoughNow;

            if (isEnoughNow == 'yes') {
              newIsEnough = 'yes';
            } else if (isEnoughNow == 'maybe') {
              newIsEnough = 'maybe';
            } else {
              newIsEnough = currentIsEnough;
            }
          } else {
            throw Exception('Please enter the amount you added');
          }
        } else if (_wouldLikeToAdd == 'no') {
          newIsEnough =
              _userOpinion;
        } else {
          newIsEnough = currentIsEnough;
        }
      } else {
        newIsEnough = currentIsEnough;
      }

      if (isPetShopOwner && !shouldShowDonateQuestion) {
        addedAmount = null;
        addedByUserId = null;
        isEnoughNow = null;
      }
      if (shouldShowDonateQuestion) {
        addedAmount = null;
        addedByUserId = null;
        isEnoughNow = null;
      }

      final updateResponse = await _apiService.updateMarker(
        widget.markerId,
        isWaterEnough: newIsEnough,
        addedAmount: addedAmount,
        addedByUserId: addedByUserId,
        isEnoughNow: isEnoughNow,
        catFoodAmount: shouldShowDonateQuestion ? newCatFoodAmount : null,
        dogFoodAmount: shouldShowDonateQuestion ? newDogFoodAmount : null,
        shouldUpdateCatDogAmounts:
            shouldShowDonateQuestion,
      );

      final updatedMarker = updateResponse['marker'] as Map<String, dynamic>?;

      final hasDonated = shouldShowDonateQuestion &&
          _wouldLikeToDonate == 'yes' &&
          _donatePetType != null &&
          _donateKilosController.text.isNotEmpty;
      final hasCancelledDonation =
          shouldShowDonateQuestion && _wouldLikeToDonate == 'no';

      if ((addedByUserId != null || hasDonated || hasCancelledDonation) &&
          mounted) {
        if (hasDonated || hasCancelledDonation) {
          await _loadMarkerData();
        } else {
          setState(() {
            _currentMarkerData['addedAmount'] =
                updatedMarker?['addedAmount'] ?? addedAmount;
            _currentMarkerData['addedByUserId'] =
                updatedMarker?['addedByUserId'] ?? addedByUserId;
            _currentMarkerData['isEnoughNow'] =
                updatedMarker?['isEnoughNow'] ?? isEnoughNow;
            _currentMarkerData['isWaterEnough'] =
                updatedMarker?['isWaterEnough'] ?? newIsEnough;
            });
        }

        if (addedByUserId != null) {
          await _loadAddedByUserInfo();
        }
      }

      if (mounted) {
        double? finalCatFoodAmount;
        double? finalDogFoodAmount;

        if (shouldShowDonateQuestion) {
          if (hasDonated || hasCancelledDonation) {
            finalCatFoodAmount = _currentMarkerData['catFoodAmount'] != null
                ? ((_currentMarkerData['catFoodAmount'] is int)
                    ? (_currentMarkerData['catFoodAmount'] as int).toDouble()
                    : (_currentMarkerData['catFoodAmount'] as num).toDouble())
                : null;
            finalDogFoodAmount = _currentMarkerData['dogFoodAmount'] != null
                ? ((_currentMarkerData['dogFoodAmount'] is int)
                    ? (_currentMarkerData['dogFoodAmount'] as int).toDouble()
                    : (_currentMarkerData['dogFoodAmount'] as num).toDouble())
                    : null;
          } else {
            finalCatFoodAmount = updatedMarker?['catFoodAmount'] != null
                ? ((updatedMarker?['catFoodAmount'] is int)
                    ? (updatedMarker?['catFoodAmount'] as int).toDouble()
                    : (updatedMarker?['catFoodAmount'] as num).toDouble())
                : newCatFoodAmount;
            finalDogFoodAmount = updatedMarker?['dogFoodAmount'] != null
                ? ((updatedMarker?['dogFoodAmount'] is int)
                    ? (updatedMarker?['dogFoodAmount'] as int).toDouble()
                    : (updatedMarker?['dogFoodAmount'] as num).toDouble())
                : newDogFoodAmount;
          }
        } else {
          finalCatFoodAmount = null;
          finalDogFoodAmount = null;
        }

        Navigator.pop(context, {
          'markerId': widget.markerId,
          'isWaterEnough': updatedMarker?['isWaterEnough'] ?? newIsEnough,
          'addedAmount': updatedMarker?['addedAmount'] ?? addedAmount,
          'addedByUserId': updatedMarker?['addedByUserId'] ?? addedByUserId,
          'isEnoughNow': updatedMarker?['isEnoughNow'] ?? isEnoughNow,
          'catFoodAmount': finalCatFoodAmount,
          'dogFoodAmount': finalDogFoodAmount,
        });

        if (hasDonated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Thank you for your donation :)',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } else if (hasCancelledDonation) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Donation cancelled',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
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
    final markerData = _currentMarkerData;

    final markerType = markerData['type'] as String? ?? '';
    final petType = markerData['petType'] as String?;
    final waterLiters = markerData['waterLiters'] as double?;
    final catFoodAmount = markerData['catFoodAmount'] != null
        ? ((markerData['catFoodAmount'] is int)
            ? (markerData['catFoodAmount'] as int).toDouble()
            : (markerData['catFoodAmount'] as num).toDouble())
        : null;
    final dogFoodAmount = markerData['dogFoodAmount'] != null
        ? ((markerData['dogFoodAmount'] is int)
            ? (markerData['dogFoodAmount'] as int).toDouble()
            : (markerData['dogFoodAmount'] as num).toDouble())
        : null;
    final isWaterEnough = markerData['isWaterEnough'] as String?;
    final hasAddedBy = markerData['addedByUserId'] != null;
    final addedAmount = markerData['addedAmount'];

    final catAmount = catFoodAmount ?? 0.0;
    final dogAmount = dogFoodAmount ?? 0.0;

    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    final isPetShopOwner = currentUser?.userType == 'pet_shop_owner';

    final markerUserId = markerData['userId'] as String?;
    final markerUserType = markerData['userType'] as String?;
    final isMarkerOwnerPetShopOwner = markerUserType == 'pet_shop_owner';
    final isCurrentUserMarkerOwner = currentUser?.id == markerUserId;
    final shouldShowDonateQuestion =
        isMarkerOwnerPetShopOwner && isCurrentUserMarkerOwner;
    final shouldShowOpinionSection = isPetShopOwner
        ? (isMarkerOwnerPetShopOwner &&
            isCurrentUserMarkerOwner)
        : (!isMarkerOwnerPetShopOwner ||
            isCurrentUserMarkerOwner);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24.0),
      child: Container(
        decoration: BoxDecoration(
          color:  Color(0xFF64B5F6),
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
                Text(
                  'Marker Details',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (hasAddedBy)
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
                                    const Icon(Icons.person_add,
                                        color: Colors.grey, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                    const Icon(Icons.person,
                                        color: Colors.grey, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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

                      if (isMarkerOwnerPetShopOwner &&
                          catFoodAmount == null &&
                          dogFoodAmount == null) ...[
                      ] else ...[
                        if (isMarkerOwnerPetShopOwner) ...[
                          _buildInfoRow(
                            'Cat',
                            '${catAmount.toStringAsFixed(1)} kilograms',
                            Icons.pets,
                          ),
                          const SizedBox(height: 12),

                          _buildInfoRow(
                            'Dog',
                            '${dogAmount.toStringAsFixed(1)} kilograms',
                            Icons.pets,
                          ),
                          const SizedBox(height: 20),
                        ] else ...[
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
                        ],

                        if (!isMarkerOwnerPetShopOwner) ...[
                          if (hasAddedBy && addedAmount != null)
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
                            _buildInfoRow(
                              markerType == 'water'
                                  ? 'Water Amount'
                                  : 'Food Amount',
                              '${waterLiters.toStringAsFixed(1)} ${markerType == 'water' ? 'liters' : 'kilograms'}',
                              markerType == 'water'
                                  ? Icons.water_drop
                                  : Icons.restaurant,
                            ),
                          if ((hasAddedBy && addedAmount != null) ||
                              waterLiters != null)
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
                        ],
                      ],

                      if (shouldShowOpinionSection) ...[
                        const Divider(
                          thickness: 1,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your Opinion',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 16),

                        if (shouldShowDonateQuestion) ...[
                          Text(
                            'Would you like to donate?',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _wouldLikeToDonate,
                            style: const TextStyle(color: Colors.black87),
                            dropdownColor: Colors.white,
                            decoration: InputDecoration(
                              labelText: 'Select an option',
                              labelStyle: const TextStyle(color: Colors.grey),
                              prefixIcon: const Icon(Icons.favorite,
                                  color: Colors.grey),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Colors.grey),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color:  Color(0xFF64B5F6), width: 2),
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
                                _wouldLikeToDonate = value;
                                if (value == 'no') {
                                  _donatePetType = null;
                                  _donateKilosController.clear();
                                }
                              });
                            },
                            validator: (value) {
                              if (shouldShowDonateQuestion &&
                                  (value == null || value.isEmpty)) {
                                return 'Please select an option';
                              }
                              return null;
                            },
                          ),
                          if (_wouldLikeToDonate == 'yes') ...[
                            const SizedBox(height: 16),
                            Text(
                              'Cat or Dog?',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _donatePetType,
                              style: const TextStyle(color: Colors.black87),
                              dropdownColor: Colors.white,
                              decoration: InputDecoration(
                                labelText: 'Select an option',
                                labelStyle: const TextStyle(color: Colors.grey),
                                prefixIcon:
                                    const Icon(Icons.pets, color: Colors.grey),
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: Colors.grey),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: Colors.grey),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color:  Color(0xFF64B5F6), width: 2),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem<String>(
                                  value: 'cat',
                                  child: Text('Cat'),
                                ),
                                DropdownMenuItem<String>(
                                  value: 'dog',
                                  child: Text('Dog'),
                                ),
                              ],
                              onChanged: (String? value) {
                                setState(() {
                                  _donatePetType = value;
                                  if (value == null) {
                                    _donateKilosController.clear();
                                  }
                                });
                              },
                              validator: (value) {
                                if (_wouldLikeToDonate == 'yes' &&
                                    (value == null || value.isEmpty)) {
                                  return 'Please select an option';
                                }
                              return null;
                            },
                          ),
                            if (_donatePetType != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                'How many kilos would you like to donate?',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _donateKilosController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                style: const TextStyle(color: Colors.black87),
                                decoration: InputDecoration(
                                  labelText: 'Enter amount in kilos',
                                  labelStyle:
                                      const TextStyle(color: Colors.grey),
                                  prefixIcon: const Icon(Icons.restaurant,
                                      color: Colors.grey),
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        const BorderSide(color: Colors.grey),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        const BorderSide(color: Colors.grey),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color:  Color(0xFF64B5F6), width: 2),
                                  ),
                                ),
                                validator: (value) {
                                  if (_wouldLikeToDonate == 'yes' &&
                                      _donatePetType != null &&
                                      (value == null || value.isEmpty)) {
                                    return 'Please enter the amount';
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
                            ],
                          ],
                        ] else ...[
                          Text(
                            markerType == 'water'
                                ? 'Is Water Enough?'
                                : 'Is Food Enough?',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
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
                              prefixIcon: const Icon(Icons.rate_review,
                                  color: Colors.grey),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Colors.grey),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color:  Color(0xFF64B5F6), width: 2),
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
                                if (!isPetShopOwner &&
                                    value != 'maybe' &&
                                    value != 'no') {
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
                          if (!isPetShopOwner &&
                              (_userOpinion == 'maybe' ||
                                  _userOpinion == 'no')) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Would you like to add?',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
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
                                  borderSide:
                                      const BorderSide(color: Colors.grey),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: Colors.grey),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color:  Color(0xFF64B5F6), width: 2),
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
                                  if (value == 'no') {
                                    _addedAmountController.clear();
                                    _isEnoughNow = null;
                                  }
                                });
                              },
                              validator: (value) {
                                if ((_userOpinion == 'maybe' ||
                                        _userOpinion == 'no') &&
                                    (value == null || value.isEmpty)) {
                                  return 'Please select an option';
                                }
                              return null;
                            },
                          ),
                            if (_wouldLikeToAdd == 'yes') ...[
                              const SizedBox(height: 16),
                              Text(
                                markerType == 'water'
                                    ? 'How many liters of water did you add?'
                                    : 'How many kilograms of food did you add?',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _addedAmountController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                style: const TextStyle(color: Colors.black87),
                                decoration: InputDecoration(
                                  labelText: 'Enter amount',
                                  labelStyle:
                                      const TextStyle(color: Colors.grey),
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
                                    borderSide:
                                        const BorderSide(color: Colors.grey),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        const BorderSide(color: Colors.grey),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color:  Color(0xFF64B5F6), width: 2),
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
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
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
                                  labelStyle:
                                      const TextStyle(color: Colors.grey),
                                  prefixIcon: const Icon(Icons.check_circle,
                                      color: Colors.grey),
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        const BorderSide(color: Colors.grey),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        const BorderSide(color: Colors.grey),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color:  Color(0xFF64B5F6), width: 2),
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
                        ],
                      ],
                      const SizedBox(height: 24),

                      if (shouldShowOpinionSection)
                        ElevatedButton(
                          onPressed: _isLoading ? null : _submitOpinion,
                          style: ButtonStyle(
                            backgroundColor:
                                MaterialStateProperty.all(Color(0xFF64B5F6)),
                            foregroundColor:
                                MaterialStateProperty.all(Colors.white),
                            side: MaterialStateProperty.all(
                              BorderSide(color: Color(0xFF64B5F6), width: 2),
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
                              : Text(
                                  shouldShowDonateQuestion
                                      ? 'Submit'
                                      : 'Submit Opinion',
                                  style: const TextStyle(fontSize: 16),
                                ),
                        ),
                      if (shouldShowOpinionSection) const SizedBox(height: 16),

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
