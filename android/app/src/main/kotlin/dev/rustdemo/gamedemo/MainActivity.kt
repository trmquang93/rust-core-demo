package dev.rustdemo.gamedemo

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.abs
import uniffi.game_core.Direction
import uniffi.game_core.Game

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Debug aid for screenshots: `am start ... --ei autoplay N` makes N scripted moves.
        val autoplay = intent.getIntExtra("autoplay", 0)
        setContent { GameScreen(autoplay) }
    }
}

/** UI only. All rules live in the Rust `Game` object (generated bindings in uniffi/game_core). */
@Composable
fun GameScreen(autoplay: Int) {
    var game by remember { mutableStateOf(Game(42UL)) }
    var cells by remember { mutableStateOf(game.cells()) }
    var score by remember { mutableStateOf(game.score()) }
    var over by remember { mutableStateOf(false) }

    fun refresh() {
        cells = game.cells(); score = game.score(); over = game.isOver()
    }
    fun move(d: Direction) { game.slide(d); refresh() }

    LaunchedEffect(Unit) {
        val order = listOf(Direction.LEFT, Direction.UP, Direction.RIGHT, Direction.DOWN)
        for (step in 0 until autoplay) move(order[step % 4])
    }

    Column(
        Modifier.fillMaxSize().padding(16.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("Rust core · Compose UI", fontSize = 18.sp, fontWeight = FontWeight.SemiBold)
        Spacer(Modifier.height(12.dp))
        Text("Score $score", fontSize = 34.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(20.dp))

        Column(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(Color(0xFFBDBDBD))
                .padding(8.dp)
                .pointerInput(Unit) {
                    var dx = 0f; var dy = 0f
                    detectDragGestures(
                        onDragStart = { dx = 0f; dy = 0f },
                        onDrag = { _, a -> dx += a.x; dy += a.y },
                        onDragEnd = {
                            if (abs(dx) > 20 || abs(dy) > 20) {
                                move(
                                    if (abs(dx) > abs(dy)) (if (dx > 0) Direction.RIGHT else Direction.LEFT)
                                    else (if (dy > 0) Direction.DOWN else Direction.UP)
                                )
                            }
                        },
                    )
                },
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            for (r in 0 until 4) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    for (c in 0 until 4) {
                        Tile(cells.getOrElse(r * 4 + c) { 0u }.toInt(), Modifier.weight(1f))
                    }
                }
            }
        }

        Spacer(Modifier.height(20.dp))
        if (over) Text("Game over", color = Color.Red, fontSize = 22.sp, fontWeight = FontWeight.Bold)
        Button(onClick = { game = Game(System.nanoTime().toULong() or 1UL); refresh() }) { Text("New game") }
    }
}

@Composable
fun Tile(value: Int, modifier: Modifier) {
    val bg = when (value) {
        0 -> Color(0xFFD9D9D9)
        2 -> Color(0xFFEDE3D9)
        4 -> Color(0xFFEDE0C8)
        8 -> Color(0xFFF2B179)
        16 -> Color(0xFFF59563)
        32 -> Color(0xFFF67C5F)
        64 -> Color(0xFFF65E3B)
        else -> Color(0xFFEDCF73)
    }
    Box(
        modifier.aspectRatio(1f).clip(RoundedCornerShape(8.dp)).background(bg),
        contentAlignment = Alignment.Center,
    ) {
        if (value != 0) {
            Text(
                "$value", fontSize = 28.sp, fontWeight = FontWeight.Bold,
                color = if (value <= 4) Color(0xFF333333) else Color.White,
            )
        }
    }
}
