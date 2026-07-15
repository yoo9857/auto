# N200: 5-card news flow

1. **Hook** — one clear news signal and headline.
2. **Evidence video** — select the newest topic-matched source video first, then show it in full with only a compact source strip over it.
3. **Analysis** — explain the business or market mechanism.
4. **Judgment** — state the editorial conclusion and its conditions.
5. **CTA** — keep the brand close and invite the next action.

## Non-negotiable layout rules

- Use a 1080 x 1350 (4:5) canvas.
- The evidence video uses `contain`, never crop. Black side bars are intentional when needed.
- Put the title and summary below the video, never over the key visual.
- Keep the footer position, logo scale, palette, and page count consistent across all five cards.
- One message per card; do not add category chips or decorative UI above the video.

## Publishing gate

`article_ingested -> topic_profiled -> source_collected -> facts_checked -> rights_reviewed -> rendered -> ready_to_post`

External newsroom video is `review_required` until the publishing licence or permission is confirmed. A source link alone is not a reuse licence.

Use `select_x_video_candidate.ps1` before approval. It confirms video metadata, requires a topic match, and chooses newest valid footage; it does not publish or download automatically.

If no event-evidence clip exists, an eligible named person can use a separate **person-context** fallback: interview, speech, annual meeting, remarks, or conversation footage. This must be labelled `CONTEXT VIDEO` and can never be used as proof of the article event.

`generate_carousel.ps1 -SelectXVideo` enables this discovery step for article types with a high-confidence topic profile. If no safe topic entity can be derived, the workflow stops for editorial topic input instead of searching vague keywords.
