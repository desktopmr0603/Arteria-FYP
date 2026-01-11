import 'package:arteria/features/auth/presentation/cubits/auth_cubits.dart';
import 'package:arteria/features/auth/presentation/cubits/auth_states.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  // Date of Birth Selection
  int? _selectedYear;
  int? _selectedMonth;
  int? _selectedDay;
  
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  String? _selectedGender;
  String? _birthdayError;
  String? _heightError;
  String? _weightError;
  String? _genderError;

  // Generate year list (from current year going back 120 years)
  List<int> get _years {
    final currentYear = DateTime.now().year;
    return List.generate(120, (i) => currentYear - i);
  }

  // Month names for better readability
  final List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  // Generate days based on selected month and year
  List<int> get _days {
    if (_selectedMonth == null) return List.generate(31, (i) => i + 1);
    int daysInMonth = 31;
    if ([4, 6, 9, 11].contains(_selectedMonth)) {
      daysInMonth = 30;
    } else if (_selectedMonth == 2) {
      if (_selectedYear != null && 
          (_selectedYear! % 4 == 0 && (_selectedYear! % 100 != 0 || _selectedYear! % 400 == 0))) {
        daysInMonth = 29;
      } else {
        daysInMonth = 28;
      }
    }
    return List.generate(daysInMonth, (i) => i + 1);
  }

  // Calculate age from selected date
  int? get _calculatedAge {
    if (_selectedYear == null || _selectedMonth == null || _selectedDay == null) {
      return null;
    }
    final now = DateTime.now();
    final birthDate = DateTime(_selectedYear!, _selectedMonth!, _selectedDay!);
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month || 
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  DateTime? _calculateBirthdayFromSelection() {
    if (_selectedYear == null || _selectedMonth == null || _selectedDay == null) {
      return null;
    }
    return DateTime(_selectedYear!, _selectedMonth!, _selectedDay!);
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
      if (_selectedYear == null || _selectedMonth == null || _selectedDay == null) {
        _birthdayError = 'Please select your complete date of birth';
        isValid = false;
      } else if (_calculatedAge == null || _calculatedAge! < 1 || _calculatedAge! > 120) {
        _birthdayError = 'Please select a valid date of birth';
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
      final birthday = _calculateBirthdayFromSelection();

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'birthday': birthday != null ? Timestamp.fromDate(birthday) : null,
        'age': _calculatedAge,
        'height': double.parse(_heightController.text),
        'weight': double.parse(_weightController.text),
        'gender': _selectedGender,
      });

      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading dialog
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

  // Simple Date of Birth Selector - Elderly Friendly
  Widget _buildAgeSelector() {
    return Column(
      children: [
        // Simple instruction text
        Text(
          'Select your date of birth',
          style: GoogleFonts.openSans(
            fontSize: 16,
            color: const Color(0xFF4B4B4B),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),

        // Year Dropdown
        _buildDropdownField(
          label: 'Year',
          value: _selectedYear,
          items: _years,
          displayText: (year) => year.toString(),
          onChanged: (year) {
            setState(() {
              _selectedYear = year;
              // Adjust day if needed for February
              if (_selectedDay != null && !_days.contains(_selectedDay)) {
                _selectedDay = _days.last;
              }
              _birthdayError = null;
            });
          },
        ),
        const SizedBox(height: 16),

        // Month Dropdown
        _buildDropdownField(
          label: 'Month',
          value: _selectedMonth,
          items: List.generate(12, (i) => i + 1),
          displayText: (month) => _monthNames[month - 1],
          onChanged: (month) {
            setState(() {
              _selectedMonth = month;
              // Adjust day if needed
              if (_selectedDay != null && !_days.contains(_selectedDay)) {
                _selectedDay = _days.last;
              }
              _birthdayError = null;
            });
          },
        ),
        const SizedBox(height: 16),

        // Day Dropdown
        _buildDropdownField(
          label: 'Day',
          value: _selectedDay,
          items: _days,
          displayText: (day) => day.toString(),
          onChanged: (day) {
            setState(() {
              _selectedDay = day;
              _birthdayError = null;
            });
          },
        ),

        if (_birthdayError != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              _birthdayError!,
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

  // Reusable dropdown field with large touch targets
  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) displayText,
    required void Function(T?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.openSans(
            fontSize: 14,
            color: const Color(0xFF6B6B6B),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: value != null 
                  ? const Color(0xFFE63946) 
                  : Colors.grey.shade300,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              hint: Text(
                'Select $label',
                style: GoogleFonts.openSans(
                  fontSize: 18,
                  color: Colors.grey.shade400,
                ),
              ),
              isExpanded: true,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: value != null 
                    ? const Color(0xFFE63946) 
                    : Colors.grey.shade400,
                size: 28,
              ),
              style: GoogleFonts.openSans(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1A1A),
              ),
              dropdownColor: Colors.white,
              menuMaxHeight: 300,
              items: items.map((item) {
                return DropdownMenuItem<T>(
                  value: item,
                  child: Text(
                    displayText(item),
                    style: GoogleFonts.openSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
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
                        // Age Selection Page - Modern & Elderly Friendly
                        _buildPage(
                          title: 'Your Age',
                          content: _buildAgeSelector(),
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
