package com.missiveapp.openwith;

import android.content.ClipData;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ProviderInfo;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.provider.OpenableColumns;
import android.webkit.URLUtil;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

/**
 * Handle serialization of Android objects ready to be sent to javascript.
 */
class Serializer {
  /** Convert an intent to JSON.
   *
   * This actually only exports stuff necessary to see file content
   * (streams or clip data) sent with the intent.
   * If none are specified, null is return.
   */
  public static JSONObject toJSONObject(
          final Context context,
          final Intent intent)
         throws JSONException
  {
    JSONArray items = null;

    if ("text/plain".equals(intent.getType())) {
      items = itemsFromIntent(intent);
    } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
      items = itemsFromClipData(context, intent.getClipData());
    }

    if (items == null || items.length() == 0) {
      items = itemsFromExtras(context, intent.getExtras());
    }

    if (items == null) {
      return null;
    }

    final JSONObject action = new JSONObject();
    action.put("action", translateAction(intent.getAction()));
    action.put("items", items);

    return action;
  }

  public static String translateAction(final String action) {
    if ("android.intent.action.SEND".equals(action) ||
        "android.intent.action.SEND_MULTIPLE".equals(action)) {
      return "SEND";
    } else if ("android.intent.action.VIEW".equals(action)) {
      return "VIEW";
    }

    return action;
  }

  /** Extract the list of items from an intent (plain text).
   *
   * Defaults to null. */
  public static JSONArray itemsFromIntent(
         final Intent intent)
        throws JSONException
  {
    if (intent != null) {
      String text = intent.getStringExtra(Intent.EXTRA_TEXT);
      String type = "text/plain";

      if (URLUtil.isValidUrl(text)) {
        type = "url";
      }

      final JSONObject json = new JSONObject();
      json.put("data", text);
      json.put("type", type);

      JSONObject[] items = new JSONObject[1];
      items[0] = json;

      return new JSONArray(items);
    }

    return null;
  }

  /** Extract the list of items from clip data (if available).
   *
   * Defaults to null. */
  public static JSONArray itemsFromClipData(
          final Context context,
          final ClipData clipData)
         throws JSONException
  {
    if (clipData != null) {
      final int clipItemCount = clipData.getItemCount();
      final JSONArray items = new JSONArray();

      for (int i = 0; i < clipItemCount; i++) {
        final JSONObject item = toJSONObject(context, clipData.getItemAt(i).getUri());
        if (item != null) {
          items.put(item);
        }
      }

      return items;
    }

    return null;
  }

  /** Extract the list of items from the intent's extra stream.
   *
   * See Intent.EXTRA_STREAM for details. */
  public static JSONArray itemsFromExtras(
          final Context context,
          final Bundle extras)
         throws JSONException
  {
    if (extras == null) {
      return null;
    }

    final Object stream = extras.get(Intent.EXTRA_STREAM);
    if (!(stream instanceof Uri)) {
      return null;
    }

    final JSONObject item = toJSONObject(context, (Uri) stream);

    if (item == null) {
      return null;
    }

    final JSONObject[] items = new JSONObject[1];
    items[0] = item;

    return new JSONArray(items);
  }

  /** Convert an Uri to JSON object.
   *
   * Object will include:
   *    "fileUrl" itself;
   *    "type" of data;
   *    "name" for the file.
   */
  public static JSONObject toJSONObject(
          final Context context,
          final Uri uri)
         throws JSONException
  {
    if (!isShareableUri(context, uri)) {
      return null;
    }

    final ContentResolver contentResolver = context.getContentResolver();
    final JSONObject json = new JSONObject();
    final String type = contentResolver.getType(uri);
    final String suggestedName = getNamefromURI(contentResolver, uri);

    json.put("fileUrl", uri);
    json.put("type", type);
    json.put("name", suggestedName);

    return json;
  }

  public static boolean isShareableUri(
          final Context context,
          final Uri uri)
  {
    if (uri == null || !"content".equalsIgnoreCase(uri.getScheme()) || uri.getHost() == null) {
      return false;
    }

    final ProviderInfo provider = context.getPackageManager().resolveContentProvider(uri.getHost(), 0);

    return provider == null || !context.getPackageName().equals(provider.packageName);
  }

  public static String getNamefromURI(
          final ContentResolver contentResolver,
          final Uri uri)
  {
    final Cursor cursor = contentResolver.query(uri, null, null, null, null);

    if (cursor == null) {
      return "";
    }

    final int column_index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
    if (column_index < 0) {
      cursor.close();
      return "";
    }

    if (!cursor.moveToFirst()) {
      cursor.close();
      return "";
    }

    final String result = cursor.getString(column_index);
    cursor.close();

    return result;
  }
}
