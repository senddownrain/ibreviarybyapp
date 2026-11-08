/** A narrow bundle repair. The Web audit owns liturgical rules and HTML edits.
 * No schema, document set, non-psalm field or published revision is changed. */
export function repairPsalmodyBundle({ read, repairDocument, psalmFields, plain, generated, names }) {
  const updates = {};
  for (const name of names) {
    const original = read(name);
    const canonical = ['liturgicalTemplates', 'liturgicalProperTexts'].includes(name)
      ? new Map(generated(name === 'liturgicalTemplates' ? 'db-templates' : 'db-feasts').map(d => [d.id, d]))
      : new Map();
    let changed = false;
    const documents = Object.entries(original).map(([id, doc]) => {
      const { after, changes } = repairDocument(doc);
      if (!changes.length) return doc;
      changed = true;
      // Use the exact generated canonical HTML for the fields being repaired,
      // after checking that it differs only in the doxology/formatting.
      const source = canonical.get(id);
      if (source) {
        const fields = new Map(psalmFields(source).map(f => [f.path.join('.'), f.value]));
        for (const change of changes) {
          const expected = fields.get(change.field);
          if (typeof expected !== 'string') throw Error(`Missing canonical field ${name}/${id}.${change.field}`);
          const parent = change.path.slice(0, -1).reduce((v, k) => v[k], after);
          const key = change.path.at(-1);
          if (plain(parent[key]) !== plain(expected)) throw Error(`Text drift outside doxology: ${name}/${id}.${change.field}`);
          parent[key] = expected;
        }
      }
      if (repairDocument(after).changes.length) throw Error(`Non-idempotent repair ${name}/${id}`);
      return after;
    });
    if (changed) updates[name] = documents;
  }
  return updates;
}
