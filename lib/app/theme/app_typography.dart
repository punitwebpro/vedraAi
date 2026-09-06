import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Vedra typography system.
abstract final class AppTypography {
  static const TextStyle display = TextStyle(
      fontSize: 32,
          fontWeight: FontWeight.w700,
              height: 1.15,
                  color: AppColors.textPrimary,
                    );

                      static const TextStyle headline = TextStyle(
                          fontSize: 24,
                              fontWeight: FontWeight.w700,
                                  height: 1.2,
                                      color: AppColors.textPrimary,
                                        );

                                          static const TextStyle title = TextStyle(
                                              fontSize: 20,
                                                  fontWeight: FontWeight.w600,
                                                      height: 1.25,
                                                          color: AppColors.textPrimary,
                                                            );

                                                              static const TextStyle body = TextStyle(
                                                                  fontSize: 16,
                                                                      fontWeight: FontWeight.w400,
                                                                          height: 1.5,
                                                                              color: AppColors.textPrimary,
                                                                                );

                                                                                  static const TextStyle bodySecondary = TextStyle(
                                                                                      fontSize: 15,
                                                                                          fontWeight: FontWeight.w400,
                                                                                              height: 1.45,
                                                                                                  color: AppColors.textSecondary,
                                                                                                    );

                                                                                                      static const TextStyle caption = TextStyle(
                                                                                                          fontSize: 13,
                                                                                                              fontWeight: FontWeight.w400,
                                                                                                                  height: 1.4,
                                                                                                                      color: AppColors.textMuted,
                                                                                                                        );

                                                                                                                          static const TextStyle button = TextStyle(
                                                                                                                              fontSize: 15,
                                                                                                                                  fontWeight: FontWeight.w600,
                                                                                                                                      height: 1.2,
                                                                                                                                          color: Colors.white,
                                                                                                                                            );
                                                                                                                                            }