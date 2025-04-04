import 'dart:math';
import 'package:flutter/material.dart';

class AudioWaveform extends StatefulWidget {
  final Color color;
  final int barCount;
  
  const AudioWaveform({
    Key? key,
    required this.color,
    this.barCount = 30,
  }) : super(key: key);

  @override
  State<AudioWaveform> createState() => _AudioWaveformState();
}

class _AudioWaveformState extends State<AudioWaveform> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late List<double> _barHeights;
  final Random _random = Random();
  
  @override
  void initState() {
    super.initState();
    _barHeights = List.generate(widget.barCount, (_) => _getRandomHeight());
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _updateBarHeights();
        _animationController.reset();
        _animationController.forward();
      }
    });
    
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  double _getRandomHeight() {
    return 0.2 + _random.nextDouble() * 0.8;
  }
  
  void _updateBarHeights() {
    setState(() {
      for (int i = 0; i < widget.barCount; i++) {
        _barHeights[i] = _getRandomHeight();
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
            widget.barCount,
            (index) {
              final height = _barHeights[index] * _animationController.value +
                  _barHeights[(index + 1) % widget.barCount] * (1 - _animationController.value);
              
              return _buildBar(height);
            },
          ),
        );
      },
    );
  }
  
  Widget _buildBar(double heightFactor) {
    return Container(
      width: 4,
      height: 48 * heightFactor,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
} 