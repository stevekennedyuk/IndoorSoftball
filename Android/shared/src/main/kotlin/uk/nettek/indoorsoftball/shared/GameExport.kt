package uk.nettek.indoorsoftball.shared

import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

// Results export: the text document saved for each finished game, its file
// name, and the subject used when sharing it. Port of iOS GameExport.swift –
// the output must match the iOS app character for character.

private fun stamp(ms: Long, pattern: String, zone: ZoneId): String =
    DateTimeFormatter.ofPattern(pattern, Locale.US).withZone(zone).format(Instant.ofEpochMilli(ms))

/** Removes characters that aren't allowed (or are awkward) in file names. */
fun fileSafe(name: String, fallback: String): String {
    val banned = "/\\:?%*|\"<>\n\r\t"
    var s = name.split(*banned.map { it.toString() }.toTypedArray()).joinToString("-")
    s = s.trim { it.isWhitespace() || it == '.' }
    if (s.isEmpty()) s = fallback
    return s.take(40).trim()
}

/**
 * home-away-location-date&time, e.g.
 * "Owls-Hawks-Hackney Leisure Centre-2026-11-08 1930.txt", or
 * "Home-Away-Location-2026-11-08 1930.txt" if nothing was entered.
 */
fun Game.exportFileName(zone: ZoneId = ZoneId.systemDefault()): String =
    listOf(
        fileSafe(homeName, "Home"),
        fileSafe(awayName, "Away"),
        fileSafe(place, "Location"),
        stamp(playStart, "yyyy-MM-dd HHmm", zone),
    ).joinToString("-") + ".txt"

/** Subject line used when the results are shared by email. */
fun Game.shareSubject(zone: ZoneId = ZoneId.systemDefault()): String =
    "Indoor Softball: $awayName ${total(Team.AWAY).score()} – $homeName ${total(Team.HOME).score()}, " +
        "$place (${stamp(playStart, "d MMM yyyy, HH:mm", zone)})"

/**
 * The results document:
 *
 *     Hawks vs Owls : Hackney Leisure Centre : 08/11/2026 : 19:30
 *     Inning 1
 *     Hawks: +11 : -2 : 9
 *     Owls: +8 : -2 : 6
 *
 *     End Game
 *     Hawks: 16
 *     Owls: 17
 *
 * Each inning line is that team's plus, minus and total for the inning. Blank
 * names / location appear as Away, Home and Location. A half that wasn't
 * played (game ended early) shows "not played".
 */
fun Game.resultsDocument(zone: ZoneId = ZoneId.systemDefault()): String {
    val lines = mutableListOf(
        listOf("$awayName vs $homeName", place, stamp(playStart, "dd/MM/yyyy", zone), stamp(playStart, "HH:mm", zone))
            .joinToString(" : ")
    )
    for (inning in 1..maxOf(1, inningsCount)) {
        lines += "Inning $inning"
        for (team in Team.entries) {
            val h = half(team, inning) ?: continue
            lines += if (isReached(h)) {
                val minus = if (h.negative == 0) "-0" else "-${-h.negative}"
                "${name(team)}: +${h.positive} : $minus : ${h.net}"
            } else {
                "${name(team)}: not played"
            }
        }
    }
    lines += ""
    lines += if (finished) "End Game" else "Score so far"
    lines += "$awayName: ${total(Team.AWAY)}"
    lines += "$homeName: ${total(Team.HOME)}"
    return lines.joinToString("\n") + "\n"
}
