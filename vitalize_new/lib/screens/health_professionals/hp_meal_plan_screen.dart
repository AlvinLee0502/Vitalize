import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class CreateMealPlanScreen extends StatefulWidget {
  final String healthProfessionalID;
  final String mealPlanId;
  final String authorName;

  const CreateMealPlanScreen({super.key, required this.healthProfessionalID, required this.mealPlanId, required this.authorName});

  @override
  CreateMealPlanScreenState createState() => CreateMealPlanScreenState();
}

class CreateMealPlanScreenState extends State<CreateMealPlanScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _foodNameController = TextEditingController();
  final TextEditingController _caloriesController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();
  final TextEditingController _carbsController = TextEditingController();
  final TextEditingController _fatsController = TextEditingController();
  final _mealPlanFormKey = GlobalKey<FormState>();
  final _foodItemFormKey = GlobalKey<FormState>();
  final TextEditingController _mealDescriptionController = TextEditingController();
  bool isPremium = false;
  bool _isLoading = false;
  late TabController _tabController;
  File? _mealPlanImage;
  final List<File> _mealImages = [];
  String? _selectedMealPlanId;
  String? existingImageUrl;
  bool isEditMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.mealPlanId.isNotEmpty) {
      isEditMode = true;
      _loadExistingMealPlan();
    }
  }

  Future<void> _loadExistingMealPlan() async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('plans')
          .doc(widget.mealPlanId)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        setState(() {
          _titleController.text = data['name'] ?? '';
          _descriptionController.text = data['description'] ?? '';
          isPremium = data['isPremium'] ?? false;
          existingImageUrl = data['media_items'];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading meal plan: $e')),
        );
      }
    }
  }

  Future<void> _updateMealPlan() async {
    if (_mealPlanFormKey.currentState!.validate()) {
      if (_mealPlanImage == null && existingImageUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add a meal plan image')),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        String? imageUrl = existingImageUrl;

        // Upload new image if selected
        if (_mealPlanImage != null) {
          final String fileName = 'meal_plan_images/${DateTime.now().millisecondsSinceEpoch}.jpg';
          imageUrl = await _uploadImage(_mealPlanImage!, fileName);

          if (imageUrl == null) throw Exception('Failed to upload meal plan image');

          // Delete old image if exists
          if (existingImageUrl != null) {
            try {
              final ref = FirebaseStorage.instance.refFromURL(existingImageUrl!);
              await ref.delete();
            } catch (e) {
              debugPrint('Error deleting old image: $e');
            }
          }
        }

        await FirebaseFirestore.instance
            .collection('plans')
            .doc(widget.mealPlanId)
            .update({
          'name': _titleController.text,
          'description': _descriptionController.text,
          'isPremium': isPremium,
          if (imageUrl != null) 'media_items': imageUrl,
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Plan updated successfully')),
          );
          Navigator.pop(context);
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update plan: ${error.toString()}')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage({bool isMealPlan = false}) async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        if (isMealPlan) {
          _mealPlanImage = File(pickedFile.path);
        } else {
          _mealImages.add(File(pickedFile.path));
        }
      });
    }
  }

  void _showFoodBankDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add to Food Bank'),
          content: SingleChildScrollView(
            child: Form(
              key: _foodItemFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _foodNameController,
                    decoration: const InputDecoration(
                      labelText: 'Food Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _caloriesController,
                    decoration: const InputDecoration(
                      labelText: 'Calories',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _proteinController,
                    decoration: const InputDecoration(
                      labelText: 'Protein (g)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _carbsController,
                    decoration: const InputDecoration(
                      labelText: 'Carbs (g)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _fatsController,
                    decoration: const InputDecoration(
                      labelText: 'Fats (g)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_foodItemFormKey.currentState?.validate() ?? false) {
                  _submitFoodItemForm();
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
              ),
              child: const Text('Add Food Item'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Edit Meal Plan' : 'Create Meal Plan'),
        backgroundColor: Colors.purple,
        actions: [
          IconButton(
            icon: const Icon(Icons.food_bank),
            onPressed: _showFoodBankDialog,
            tooltip: 'Add to Food Bank',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.fastfood), text: 'Meal Plans'),
            Tab(icon: Icon(Icons.dining), text: 'Meals'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMealPlanForm(),
          _buildMealsForm(),
        ],
      ),
    );
  }

  Widget _buildImageUploadSection({
    required bool isMealPlan,
    required String title,
    File? singleImage,
    List<File>? multipleImages,
    String? existingImageUrl,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (isMealPlan)
          GestureDetector(
            onTap: () => _pickImage(isMealPlan: true),
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[400]!),
              ),
              child: singleImage != null
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(singleImage, fit: BoxFit.cover),
              )
                  : existingImageUrl != null
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  existingImageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                ),
              )
                  : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.add_photo_alternate,
                      size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('Tap to upload image'),
                ],
              ),
            ),
          )
        else
          Column(
            children: [
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: (multipleImages?.length ?? 0) + 1,
                  itemBuilder: (context, index) {
                    if (index == multipleImages?.length) {
                      return GestureDetector(
                        onTap: () => _pickImage(isMealPlan: false),
                        child: Container(
                          width: 120,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[400]!),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add_photo_alternate, size: 32, color: Colors.grey),
                              SizedBox(height: 4),
                              Text('Add Image'),
                            ],
                          ),
                        ),
                      );
                    }
                    return Stack(
                      children: [
                        Container(
                          width: 120,
                          margin: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              multipleImages![index],
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 12,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                multipleImages.removeAt(index);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              if (multipleImages?.isEmpty ?? true)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'At least one image is required',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Future<void> _submitMealPlanForm() async {
    if (_mealPlanFormKey.currentState!.validate()) {
      if (_mealPlanImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add a meal plan image')),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        final String fileName = 'meal_plan_images/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final imageUrl = await _uploadImage(_mealPlanImage!, fileName);

        if (imageUrl == null) throw Exception('Failed to upload meal plan image');

        await FirebaseFirestore.instance.collection('plans').add({
          'name': _titleController.text,
          'authorName': widget.authorName,
          'description': _descriptionController.text,
          'type': 'meal',
          'isPremium': isPremium,
          'media_items': imageUrl,
          'healthProfessionalID': widget.healthProfessionalID,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'active',
          'subscriberCount': 0,
          'engagementCount': 0,
          'isApproved': false,
          'mealCount': 0,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Plan created successfully')),
          );
          _resetMealPlanForm();
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create plan: ${error.toString()}')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildMealPlanForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _mealPlanFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageUploadSection(
              isMealPlan: true,
              title: 'Meal Plan Cover Image',
              singleImage: _mealPlanImage,
              existingImageUrl: existingImageUrl,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.isEmpty ?? true ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) => value?.isEmpty ?? true ? 'Description is required' : null,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Meal Plan Type',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SwitchListTile(
                      title: const Text('Premium Meal Plan'),
                      value: isPremium,
                      onChanged: (value) => setState(() => isPremium = value),
                    ),
                    if (isPremium)
                      const Text(
                        'This is a premium plan. Users will need a subscription to access.',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : (isEditMode ? _updateMealPlan : _submitMealPlanForm),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : Text(isEditMode ? 'Update Meal Plan' : 'Create Meal Plan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealsForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _foodItemFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('plans')
                  .where('healthProfessionalID', isEqualTo: widget.healthProfessionalID)
                  .where('type', isEqualTo: 'meal')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text('Something went wrong');
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final mealPlans = snapshot.data?.docs ?? [];

                if (mealPlans.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Please create a meal plan first before adding meals',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  );
                }

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Meal Plan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedMealPlanId,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          items: mealPlans.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return DropdownMenuItem<String>(
                              value: doc.id,
                              child: Text(data['name'] ?? 'Unnamed Plan'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedMealPlanId = value;
                            });
                          },
                          validator: (value) =>
                          value == null ? 'Please select a meal plan' : null,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            _buildImageUploadSection(
              isMealPlan: false,
              title: 'Meal Images',
              multipleImages: _mealImages,
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Meal Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _foodNameController,
                      decoration: const InputDecoration(
                        labelText: 'Meal Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value?.isEmpty ?? true ? 'Meal name is required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _mealDescriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Meal Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      validator: (value) => value?.isEmpty ?? true ? 'Description is required' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _caloriesController,
                            decoration: const InputDecoration(
                              labelText: 'Calories',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) =>
                            value?.isEmpty ?? true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _proteinController,
                            decoration: const InputDecoration(
                              labelText: 'Protein (g)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) =>
                            value?.isEmpty ?? true ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _carbsController,
                            decoration: const InputDecoration(
                              labelText: 'Carbs (g)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) =>
                            value?.isEmpty ?? true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _fatsController,
                            decoration: const InputDecoration(
                              labelText: 'Fats (g)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) =>
                            value?.isEmpty ?? true ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading || _mealImages.isEmpty
                    ? null
                    : () async {
                  if (_foodItemFormKey.currentState?.validate() ?? false) {
                    await _submitMealForm();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : const Text(
                  'Add Meal',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitMealForm() async {
    if (_foodItemFormKey.currentState!.validate() && _selectedMealPlanId != null) {
      if (_mealImages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one image')),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        List<String> imageUrls = [];
        for (File image in _mealImages) {
          final String fileName = 'meal_images/${DateTime.now().millisecondsSinceEpoch}_${imageUrls.length}.jpg';
          final imageUrl = await _uploadImage(image, fileName);
          if (imageUrl != null) {
            imageUrls.add(imageUrl);
          }
        }

        if (imageUrls.isEmpty) {
          throw Exception('Failed to upload images');
        }

        final double mealCalories = double.parse(_caloriesController.text);

        await FirebaseFirestore.instance.collection('meals').add({
          'name': _foodNameController.text,
          'description': _mealDescriptionController.text,
          'mealPlanId': _selectedMealPlanId,
          'calories': mealCalories,
          'protein': double.parse(_proteinController.text),
          'carbs': double.parse(_carbsController.text),
          'fats': double.parse(_fatsController.text),
          'images': imageUrls,
          'createdBy': widget.healthProfessionalID,
          'createdAt': FieldValue.serverTimestamp(),
        });

        final QuerySnapshot mealSnapshot = await FirebaseFirestore.instance
            .collection('meals')
            .where('mealPlanId', isEqualTo: _selectedMealPlanId)
            .get();

        double totalCalories = 0;
        int mealCount = mealSnapshot.docs.length;

        for (var meal in mealSnapshot.docs) {
          totalCalories += meal['calories'];
        }

        final double newAverageCalories = totalCalories / mealCount;

        await FirebaseFirestore.instance.collection('plans').doc(_selectedMealPlanId).update({
          'lastUpdated': FieldValue.serverTimestamp(),
          'mealCount': mealCount,
          'averageCalories': newAverageCalories,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Meal added successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _resetMealForm();
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add meal: ${error.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<String?> _uploadImage(File image, String storagePath) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child(storagePath);
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploaded_by': widget.healthProfessionalID,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      final uploadTask = storageRef.putFile(image, metadata);
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _submitFoodItemForm() async {
    if (_foodItemFormKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        await FirebaseFirestore.instance.collection('food_items').add({
          'name': _foodNameController.text,
          'calories': double.parse(_caloriesController.text),
          'protein': double.parse(_proteinController.text),
          'carbs': double.parse(_carbsController.text),
          'fats': double.parse(_fatsController.text),
          'createdBy': widget.healthProfessionalID,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Food item added to food bank'),
              backgroundColor: Colors.green,
            ),
          );
          _resetFoodItemForm();
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add food item: ${error.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _resetMealPlanForm() {
    _titleController.clear();
    _descriptionController.clear();
    setState(() {
      _mealPlanImage = null;
      isPremium = false;
      _isLoading = false;
    });
  }

  void _resetMealForm() {
    _foodNameController.clear();
    _mealDescriptionController.clear();
    _caloriesController.clear();
    _proteinController.clear();
    _carbsController.clear();
    _fatsController.clear();
    setState(() {
      _mealImages.clear();
      _selectedMealPlanId = null;
    });
  }

  void _resetFoodItemForm() {
    _foodNameController.clear();
    _caloriesController.clear();
    _proteinController.clear();
    _carbsController.clear();
    _fatsController.clear();
  }
}
