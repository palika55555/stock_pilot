/**
 * Sync receptúr a ich ingrediencií z Flutter do PostgreSQL.
 */
async function syncRecipes(pool, body, userId) {
  if (!pool) return { ok: false, error: 'Databáza nie je k dispozícii' };
  if (!userId || userId < 1) return { ok: false, error: 'Chýba user_id' };

  const recipes = Array.isArray(body?.recipes) ? body.recipes : [];
  const ingredients = Array.isArray(body?.ingredients) ? body.ingredients : [];

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    for (const r of recipes) {
      const localId = r.local_id != null ? Number(r.local_id) : null;
      if (localId == null || Number.isNaN(localId)) continue;

      const existing = await client.query(
        'SELECT id FROM recipes WHERE user_id = $1 AND local_id = $2',
        [userId, localId]
      );

      const vals = [
        userId, localId,
        r.name || null,
        r.finished_product_unique_id || null,
        r.finished_product_name || null,
        r.output_quantity != null ? parseFloat(r.output_quantity) : null,
        r.unit || null,
        r.production_warehouse_id != null ? Number(r.production_warehouse_id) : null,
        r.output_warehouse_id != null ? Number(r.output_warehouse_id) : null,
        r.production_time_minutes != null ? Number(r.production_time_minutes) : null,
        r.note || null,
        r.is_active != null ? Number(r.is_active) : 1,
        r.min_approval_quantity != null ? parseFloat(r.min_approval_quantity) : null,
      ];

      if (existing.rows.length > 0) {
        await client.query(
          `UPDATE recipes SET
            name=$3, finished_product_unique_id=$4, finished_product_name=$5,
            output_quantity=$6, unit=$7, production_warehouse_id=$8, output_warehouse_id=$9,
            production_time_minutes=$10, note=$11, is_active=$12, min_approval_quantity=$13
          WHERE user_id=$1 AND local_id=$2`,
          vals
        );
      } else {
        await client.query(
          `INSERT INTO recipes (
            user_id, local_id, name, finished_product_unique_id, finished_product_name,
            output_quantity, unit, production_warehouse_id, output_warehouse_id,
            production_time_minutes, note, is_active, min_approval_quantity
          ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)`,
          vals
        );
      }
    }

    for (const ing of ingredients) {
      const localId = ing.local_id != null ? Number(ing.local_id) : null;
      if (localId == null || Number.isNaN(localId)) continue;
      const existing = await client.query(
        'SELECT id FROM recipe_ingredients WHERE user_id = $1 AND local_id = $2',
        [userId, localId]
      );
      const vals = [
        userId, localId,
        ing.recipe_local_id != null ? Number(ing.recipe_local_id) : null,
        ing.product_unique_id || null,
        ing.product_name || null,
        ing.plu || null,
        ing.quantity != null ? parseFloat(ing.quantity) : null,
        ing.unit || null,
      ];
      if (existing.rows.length > 0) {
        await client.query(
          `UPDATE recipe_ingredients SET
            recipe_local_id=$3, product_unique_id=$4, product_name=$5, plu=$6,
            quantity=$7, unit=$8
          WHERE user_id=$1 AND local_id=$2`,
          vals
        );
      } else {
        await client.query(
          `INSERT INTO recipe_ingredients (
            user_id, local_id, recipe_local_id, product_unique_id, product_name, plu, quantity, unit
          ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
          vals
        );
      }
    }

    await client.query('COMMIT');
    return { ok: true, count: recipes.length };
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('[recipeSync]', err.message);
    return { ok: false, error: err.message };
  } finally {
    client.release();
  }
}

async function fetchRecipes(pool, userId) {
  if (!pool || !userId) return null;
  const client = await pool.connect();
  try {
    const recipesRes = await client.query(
      'SELECT * FROM recipes WHERE user_id = $1 ORDER BY id',
      [userId]
    );
    const ingredientsRes = await client.query(
      'SELECT * FROM recipe_ingredients WHERE user_id = $1 ORDER BY id',
      [userId]
    );
    return { recipes: recipesRes.rows, ingredients: ingredientsRes.rows };
  } catch (err) {
    console.error('[fetchRecipes]', err.message);
    return null;
  } finally {
    client.release();
  }
}

module.exports = { syncRecipes, fetchRecipes };
