import 'package:arteria/features/auth/presentation/cubits/auth_cubits.dart';
import 'package:arteria/features/auth/presentation/cubits/auth_states.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  DateTime _selectedBirthday = DateTime.now().subtract(
    const Duration(days: 365 * 18),
  );
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  String? _selectedGender;
  String? _birthdayError;
  String? _heightError;
  String? _weightError;
  String? _genderError;

  int _calculateAge(DateTime birthday) {
    final now = DateTime.now();
    int age = now.year - birthday.year;
    if (now.month < birthday.month ||
        (now.month == birthday.month && now.day < birthday.day)) {
      age--;
    }
    return age;
  }

  bool _validateCurrentPage() {
    bool isValid = true;
    setState(() {
      _birthdayError = null;
      _heightError = null;
      _weightError = null;
      _genderError = null;
    });

    if (_currentPage == 0) {
      final age = _calculateAge(_selectedBirthday);
      if (age < 1 || age > 120) {
        _birthdayError = 'Please select a valid birthday (age 1-120)';
        isValid = false;
      } else if (_selectedBirthday.isAfter(DateTime.now())) {
        _birthdayError = 'Birthday cannot be in the future';
        isValid = false;
      }
    } else if (_currentPage == 1) {
      final text = _heightController.text;
      final height = double.tryParse(text);
      if (text.isEmpty) {
        _heightError = 'Please enter your height';
        isValid = false;
      } else if (height == null || height < 50 || height > 300) {
        _heightError = 'Please enter a valid height (50-300 cm)';
        isValid = false;
      }
    } else if (_currentPage == 2) {
      final text = _weightController.text;
      final weight = double.tryParse(text);
      if (text.isEmpty) {
        _weightError = 'Please enter your weight';
        isValid = false;
      } else if (weight == null || weight < 20 || weight > 500) {
        _weightError = 'Please enter a valid weight (20-500 kg)';
        isValid = false;
      }
    } else if (_currentPage == 3) {
      if (_selectedGender == null) {
        _genderError = 'Please select your gender';
        isValid = false;
      }
    }
    return isValid;
  }

  void _nextPage() {
    if (_validateCurrentPage()) {
      if (_currentPage < 3) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
        setState(() => _currentPage++);
      } else {
        _submitProfile();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please correct the errors before continuing.'),
          backgroundColor: Color(0xFFE63946),
        ),
      );
    }
  }

  Future<void> _submitProfile() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final age = _calculateAge(_selectedBirthday);

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'birthday': Timestamp.fromDate(_selectedBirthday),
        'age': age,
        'height': double.parse(_heightController.text),
        'weight': double.parse(_weightController.text),
        'gender': _selectedGender,
      });

      if (!mounted) return;
      context.read<AuthCubits>().checkAuth();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving profile: ${e.toString()}'),
          backgroundColor: const Color(0xFFE63946),
        ),
      );
    }
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: List.generate(4, (index) {
          final isActive = index <= _currentPage;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 6,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFFE63946)
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPage({required String title, required Widget content}) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Text(
            title,
            style: GoogleFonts.montserrat(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: content,
          ),
        ],
      ),
    );
  }

  // Modern Gender Selection for 2025
  Widget _buildGenderSelection() {
    final genders = [
      {
        'label': 'Male',
        'icon': Icons.male,
        'color': const Color(0xFF2196F3), // Vibrant blue
      },
      {
        'label': 'Female',
        'icon': Icons.female,
        'color': const Color(0xFFE63946), // App's accent coral
      },
      {
        'label': 'Other',
        'icon': Icons.transgender,
        'color': const Color(0xFF7C4DFF), // Modern purple
      },
    ];

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final double spacing = 12;
            final double cardWidth = (constraints.maxWidth - (spacing * 2)) / 3;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              alignment: WrapAlignment.center,
              children: genders.map((g) {
                final String label = g['label'] as String;
                final IconData icon = g['icon'] as IconData;
                final Color color = g['color'] as Color;
                final bool isSelected = _selectedGender == label;
                final AnimationController controller = AnimationController(
                  duration: const Duration(milliseconds: 300),
                  vsync: this,
                );
                if (isSelected) {
                  controller.forward();
                } else {
                  controller.reverse();
                }

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedGender = label;
                      _genderError = null;
                    });
                    controller.forward();
                  },
                  child: Semantics(
                    label: 'Select $label gender',
                    selected: isSelected,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                        CurvedAnimation(
                          parent: controller,
                          curve: Curves.easeInOut,
                        ),
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        width: cardWidth,
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? LinearGradient(
                                  colors: [
                                    color.withOpacity(0.9),
                                    color.withOpacity(0.7),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.95),
                                    Colors.white.withOpacity(0.85),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? color : Colors.grey.shade300,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                isSelected ? 0.2 : 0.1,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              icon,
                              size: 36,
                              color: isSelected
                                  ? Colors.white
                                  : color.withOpacity(0.7),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              label,
                              style: GoogleFonts.openSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF4B4B4B),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        if (_genderError != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _genderError!,
              style: GoogleFonts.openSans(
                fontSize: 14,
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubits, AuthStates>(
      listener: (context, state) {
        if (state is AuthLoading) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(child: CircularProgressIndicator()),
          );
        } else {
          if (ModalRoute.of(context)?.isCurrent == true) {
            Navigator.pop(context);
          }
          if (state is Authenticated) {
            Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
          } else if (state is AuthError) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          }
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFDECEC), Color(0xFFE8F0FF), Color(0xFFF9FAFB)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Complete Your Profile',
                    style: GoogleFonts.montserrat(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Provide these details for better monitoring',
                    style: GoogleFonts.openSans(
                      fontSize: 15,
                      color: const Color(0xFF4B4B4B),
                    ),
                  ),
                  _buildProgressBar(),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        // Birthday Page
                        _buildPage(
                          title: 'Your Birthday',
                          content: Column(
                            children: [
                              SizedBox(
                                height: 200,
                                child: CupertinoDatePicker(
                                  mode: CupertinoDatePickerMode.date,
                                  initialDateTime: _selectedBirthday,
                                  maximumDate: DateTime.now(),
                                  minimumYear: 1900,
                                  onDateTimeChanged: (value) {
                                    setState(() => _selectedBirthday = value);
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Selected: ${_selectedBirthday.day}/${_selectedBirthday.month}/${_selectedBirthday.year}',
                                style: GoogleFonts.openSans(fontSize: 16),
                              ),
                              if (_birthdayError != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    _birthdayError!,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Height Page
                        _buildPage(
                          title: 'Your Height',
                          content: TextField(
                            controller: _heightController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Height (cm)',
                              errorText: _heightError,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),

                        // Weight Page
                        _buildPage(
                          title: 'Your Weight',
                          content: TextField(
                            controller: _weightController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Weight (kg)',
                              errorText: _weightError,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),

                        // Gender Page
                        _buildPage(
                          title: 'Your Gender',
                          content: _buildGenderSelection(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE63946),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 14,
                          ),
                        ),
                        child: Text(
                          _currentPage == 3 ? 'Submit' : 'Next',
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
