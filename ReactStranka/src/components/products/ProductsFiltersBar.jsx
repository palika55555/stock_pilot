/**
 * Filtre a triedenie zoznamu produktov (zdieľané s GET /products).
 */
export default function ProductsFiltersBar({
  warehouses,
  warehouseId,
  onWarehouseChange,
  stockFilter,
  onStockFilterChange,
  sort,
  onSortChange,
}) {
  return (
    <div className="items-filters-row" role="group" aria-label="Filtre produktov">
      <label className="items-filter-label">
        <span className="items-filter-label-text">Sklad</span>
        <select
          className="items-filter-select"
          value={warehouseId}
          onChange={(e) => onWarehouseChange(e.target.value)}
        >
          <option value="">Všetky</option>
          <option value="none">Bez skladu</option>
          {warehouses.map((w) => (
            <option key={w.id} value={String(w.id)}>
              {w.name || `Sklad #${w.id}`}
            </option>
          ))}
        </select>
      </label>
      <label className="items-filter-label">
        <span className="items-filter-label-text">Stav zásob</span>
        <select
          className="items-filter-select"
          value={stockFilter}
          onChange={(e) => onStockFilterChange(e.target.value)}
        >
          <option value="all">Všetky</option>
          <option value="low">Nízky sklad (&lt; 5 ks, &gt; 0)</option>
          <option value="out">Vypredané (0 ks)</option>
        </select>
      </label>
      <label className="items-filter-label">
        <span className="items-filter-label-text">Triedenie</span>
        <select
          className="items-filter-select"
          value={sort}
          onChange={(e) => onSortChange(e.target.value)}
        >
          <option value="name_asc">Názov A–Z</option>
          <option value="name_desc">Názov Z–A</option>
          <option value="qty_desc">Množstvo ↓</option>
          <option value="qty_asc">Množstvo ↑</option>
        </select>
      </label>
    </div>
  )
}
