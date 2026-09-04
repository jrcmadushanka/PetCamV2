package com.civdevops.petcam.core.designsystem.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext

private val DarkColorScheme = darkColorScheme(
    primary = PurpleLight,
    onPrimary = Black,

    primaryContainer = PurpleDark,
    onPrimaryContainer = White,

    secondary = Gray,
    onSecondary = Black,

    secondaryContainer = SurfaceVariant,
    onSecondaryContainer = White,

    background = Black,
    onBackground = White,

    surface = Surface,
    onSurface = White,

    surfaceVariant = SurfaceVariant,
    onSurfaceVariant = Gray,

    outline = GrayDark,

    error = ErrorRed,
    onError = White,
)

private val LightColorScheme = lightColorScheme(
    primary = Purple,
    onPrimary = White,

    primaryContainer = PurpleLight,
    onPrimaryContainer = Black,

    secondary = GrayDark,
    onSecondary = White,

    secondaryContainer = White,
    onSecondaryContainer = Black,

    background = White,
    onBackground = Black,

    surface = White,
    onSurface = Black,

    surfaceVariant = SurfaceVariant,
    onSurfaceVariant = Gray,

    outline = Gray,

    error = ErrorRed,
    onError = White,
)

@Composable
fun PetCamTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = false,
    content: @Composable () -> Unit,
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current

            if (darkTheme) {
                dynamicDarkColorScheme(context)
            } else {
                dynamicLightColorScheme(context)
            }
        }

        darkTheme -> DarkColorScheme

        else -> LightColorScheme
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = PetCamTypography,
        shapes = PetCamShapes,
        content = content,
    )
}