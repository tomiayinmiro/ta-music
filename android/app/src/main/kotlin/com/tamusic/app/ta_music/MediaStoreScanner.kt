package com.tamusic.app.ta_music

import android.content.Context
import android.provider.MediaStore

/**
 * Queries MediaStore for every indexed audio file's path, date-added, and
 * duration.
 *
 * MediaStore is used only for *discovery* — the Dart side re-reads full
 * tags (title/artist/album/genre/year/track/embedded art) per file via
 * `audiotags`, exactly as it already does on Windows. DURATION is the one
 * exception (bug 8a, device testing pass): `audiotags` returns 0/null for
 * some files, but MediaStore's own indexer usually already has an accurate
 * duration for them, so it's forwarded as a fallback rather than read a
 * second time via a slower path (decoding the file, or a native
 * MediaMetadataRetriever call) purely to re-derive something MediaStore
 * already knows.
 *
 * No `IS_MUSIC` filter — voice-memo exclusion is handled entirely on the
 * Dart side (duration + missing artist/album + folder-name/filename
 * heuristics), so real music forwarded via e.g. WhatsApp isn't
 * accidentally dropped by MediaStore's own music/non-music classification.
 */
object MediaStoreScanner {
    fun queryAudioFiles(context: Context): List<Map<String, Any?>> {
        val results = mutableListOf<Map<String, Any?>>()
        val collection = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        val projection = arrayOf(
            MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.DATE_ADDED,
            MediaStore.Audio.Media.DURATION
        )

        context.contentResolver.query(
            collection,
            projection,
            null,
            null,
            null
        )?.use { cursor ->
            val dataColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)
            val dateAddedColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_ADDED)
            val durationColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)

            while (cursor.moveToNext()) {
                val path = cursor.getString(dataColumn) ?: continue
                val dateAddedSeconds = cursor.getLong(dateAddedColumn)
                // MediaStore reports 0 (or the column can be null on very old
                // files) the same way audiotags does when it genuinely
                // doesn't know either — forwarded as null so the Dart side
                // treats "neither source knows" consistently.
                val durationMs = if (cursor.isNull(durationColumn)) null else cursor.getLong(durationColumn)
                results.add(
                    mapOf(
                        "path" to path,
                        "dateAdded" to dateAddedSeconds,
                        "durationMs" to if (durationMs != null && durationMs > 0) durationMs else null
                    )
                )
            }
        }

        return results
    }
}
