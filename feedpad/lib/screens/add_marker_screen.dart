import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class AddMarkerScreen extends StatefulWidget {
  final LatLng position;

  const AddMarkerScreen({
    super.key,
    required this.position,
  });

  @override
  State<AddMarkerScreen> createState() => _AddMarkerScreenState();
}

class _AddMarkerScreenState extends State<AddMarkerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _waterLitersController = TextEditingController();
  String? _markerType; // 'food' or 'water'
  String? _petType; // 'cat' or 'dog' (sadece food seçildiğinde)
  String? _isWaterEnough; // 'yes' or 'maybe' (sadece water seçildiğinde)

  @override
  void dispose() {
    _waterLitersController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                // Logo veya başlık
                const Icon(
                  Icons.location_on,
                  size: 80,
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                Text(
                  'Add Marker',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Select marker type',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                      // Food or Water seçimi
                      DropdownButtonFormField<String>(
                        value: _markerType,
                        style: const TextStyle(color: Colors.black87),
                        dropdownColor: Colors.white,
                        decoration: InputDecoration(
                          labelText: 'Food or Water?',
                          labelStyle: const TextStyle(color: Colors.grey),
                          prefixIcon:
                              const Icon(Icons.category, color: Colors.grey),
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
                            value: 'food',
                            child: Text('Food'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'water',
                            child: Text('Water'),
                          ),
                        ],
                        onChanged: (String? value) {
                          setState(() {
                            _markerType = value;
                            // Food seçilmediyse pet type'ı sıfırla
                            if (value != 'food') {
                              _petType = null;
                            }
                            // Water seçilmediyse ve Food + pet seçilmemişse water alanlarını sıfırla
                            if (value != 'water' && value != 'food') {
                              _waterLitersController.clear();
                              _isWaterEnough = null;
                            }
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a marker type';
                          }
                          return null;
                        },
                      ),
                      // Cat or Dog seçimi (sadece Food seçildiğinde)
                      if (_markerType == 'food') ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _petType,
                          style: const TextStyle(color: Colors.black87),
                          dropdownColor: Colors.white,
                          decoration: InputDecoration(
                            labelText: 'Cat or Dog?',
                            labelStyle: const TextStyle(color: Colors.grey),
                            prefixIcon:
                                const Icon(Icons.pets, color: Colors.grey),
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
                              _petType = value;
                              // Pet type değiştiğinde water alanlarını sıfırla
                              if (value != null) {
                                _waterLitersController.clear();
                                _isWaterEnough = null;
                              }
                            });
                          },
                          validator: (value) {
                            if (_markerType == 'food' &&
                                (value == null || value.isEmpty)) {
                              return 'Please select a pet type';
                            }
                            return null;
                          },
                        ),
                      ],
                      // Water alanları (Water seçildiğinde veya Food + Cat/Dog seçildiğinde)
                      if (_markerType == 'water' ||
                          (_markerType == 'food' && _petType != null)) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _waterLitersController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: const TextStyle(color: Colors.black87),
                          decoration: InputDecoration(
                            labelText: _markerType == 'water'
                                ? 'How many liters of water did you put on average?'
                                : 'How many kilograms of food did you put in on average?',
                            labelStyle: const TextStyle(color: Colors.grey),
                            prefixIcon: Icon(
                              _markerType == 'water'
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
                            if ((_markerType == 'water' ||
                                    (_markerType == 'food' &&
                                        _petType != null)) &&
                                (value == null || value.isEmpty)) {
                              return _markerType == 'water'
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
                        DropdownButtonFormField<String>(
                          value: _isWaterEnough,
                          style: const TextStyle(color: Colors.black87),
                          dropdownColor: Colors.white,
                          decoration: InputDecoration(
                            labelText: _markerType == 'water'
                                ? 'Do you think this water is enough?'
                                : 'Do you think this food is enough?',
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
                              _isWaterEnough = value;
                            });
                          },
                          validator: (value) {
                            if ((_markerType == 'water' ||
                                    (_markerType == 'food' &&
                                        _petType != null)) &&
                                (value == null || value.isEmpty)) {
                              return 'Please select an option';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Add Marker butonu
                      ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            // Water liters'ı float'a çevir
                            double? waterLiters;
                            if ((_markerType == 'water' ||
                                    (_markerType == 'food' &&
                                        _petType != null)) &&
                                _waterLitersController.text.isNotEmpty) {
                              waterLiters =
                                  double.parse(_waterLitersController.text);
                            }

                            Navigator.pop(context, {
                              'type': _markerType,
                              'petType': _petType,
                              'waterLiters': waterLiters,
                              'isWaterEnough': _isWaterEnough,
                              'position': widget.position,
                            });
                          }
                        },
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
                        child: const Text(
                          'Add Marker',
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
                          'Cancel',
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
}
