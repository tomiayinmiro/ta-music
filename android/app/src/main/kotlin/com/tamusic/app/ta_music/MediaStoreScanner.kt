package com.tamusic.app.ta_music

import android.content.Context
import android.provider.MediaStore

/**
 * Queries MediaStore for every indexed audio file's path and date-added.
 *
 * Deliberately minimal: MediaStore is used only for *discovery* here — the
 * Dart side re-reads full tags (title/artist/album/genre/year/track/
 * duration/embedded art) per file via `audiotags`, exactly as it already
 * does on Windows, so this doesn't need to query those columns at all.
 *
 * No `IS_MUSIC` filter — voice-memo exclusion is handled entirely on the
 * Dart side (duration + missing artist/album + folder-name heuristics), so
 * real music forwarded via e.g. WhatsApp isn't accidentally dropped by
 * MediaStore's own music/non-music classification.
 */
object MediaStoreScanner {
    fun queryAudioFiles(context: Context): List<Map<String, Any?>> {
        val results = mutableListOf<Map<String, Any?>>()
        val collection = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        val projection = arrayOf(
            MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.DATE_ADDED
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

            while (cursor.moveToNext()) {
                val path = cursor.getString(dataColumn) ?: continue
                val dateAddedSeconds = cursor.getLong(dateAddedColumn)
                results.add(
                    mapOf(
                        "path" to path,
                        "dateAdded" to dateAddedSeconds
                    )
                )
            }
        }

        return results
    }
}
