## Constitutional checks

- [ ] This PR preserves Reality → Analysis → Explanation.
- [ ] This PR does not introduce recommendation, ranking, scoring, suitability, sales, lead-generation, or quote-selection logic.
- [ ] This PR respects the module boundary:
  - Capture observes reality only.
  - Contracts defines reality only.
  - Main explains reality only.
- [ ] This PR does not mutate captured evidence inside Main.
- [ ] This PR does not add business logic or simulation logic inside Contracts.
- [ ] This PR does not add analysis or recommendation logic inside Capture.
- [ ] Any change to the Three Twin model, Digital Twin lifecycle, or constitutional boundaries is documented as a proposed constitutional amendment.
