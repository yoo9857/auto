# X video selector: consistent evidence-video discovery

Use this selector after the article topic is fixed. It discovers public X links using the existing no-API web-search script, reads each post's metadata with `yt-dlp`, and ranks only confirmed videos.

```powershell
.\select_x_video_candidate.ps1 `
  -Topic 'H200' `
  -TopicAliases 'Nvidia H200, 엔비디아 H200, China AI chip' `
  -EventTerms 'China, Beijing, approval, shipment' `
  -YtDlpPath 'C:\path\to\yt-dlp.exe'
```

The output is a ranked JSON file. `recommended_candidate` is selected only when all gates pass:

1. a real video duration is confirmed;
2. the topic or an alias appears in title/description metadata;
3. the article event terms (for example `China`, `approval`, `shipment`) are also found when they are supplied;
4. a publication date is available and inside the permitted age window;
5. duration is suitable for a news card; and
6. the candidate reaches the minimum quality grade. Within the same grade, the newest publication date wins.

The selector never downloads, reuses, or posts a video. Every candidate remains `needs_fact_check` and `review_required`; use the approval step only after verifying the article facts and publication rights.

For named-person articles, the workflow can run a second `person_context` pass. It merges X results with official YouTube search results, requires an interview/speech/annual-meeting style match, and defaults to the stricter `S` grade. A person-context result is always labelled `CONTEXT VIDEO`.

To rank a hand-curated list rather than search again, pass `-CandidatesFile` with the JSON produced by `search_x_links.ps1`.

For reproducible reruns, a candidate may include `metadata_file` pointing to a previously captured `yt-dlp --dump-single-json` result. The selector uses that cache before making a network request.

Quality grades are based on topic/event match, source trust, recency, and video duration. `SSS` requires a trusted source, a strong event match, recent publication, and a card-ready duration. The default minimum is `A`; no candidate is silently substituted when that threshold is not met.

Metadata does not prove what each shot depicts. Every eligible result therefore carries a required three-step editorial review: actual footage, article facts, and reuse rights.
