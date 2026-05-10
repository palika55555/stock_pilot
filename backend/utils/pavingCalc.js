/**
 * m² → kusy, zaokrúhlenie nahor na celú vrstvu (rovnako ako Flutter PavingStoneService).
 */
function pavingCalcFromM2(requestedM2, stone) {
  const len = Number(stone.length_mm);
  const wid = Number(stone.width_mm);
  const piecesPerLayer = Number(stone.pieces_per_layer);
  const layersPerPallet = Number(stone.layers_per_pallet);
  if (!(requestedM2 > 0) || !piecesPerLayer || !layersPerPallet || !len || !wid) {
    return null;
  }
  const m2PerPiece = (len * wid) / 1_000_000;
  const m2PerLayer = piecesPerLayer * m2PerPiece;
  const totalLayers = Math.ceil(requestedM2 / m2PerLayer);
  const totalPieces = totalLayers * piecesPerLayer;
  const fullPallets = Math.floor(totalLayers / layersPerPallet);
  const remainingLayers = totalLayers % layersPerPallet;
  const partialPieces = remainingLayers * piecesPerLayer;
  const actualM2 = totalPieces * m2PerPiece;
  return {
    totalPieces,
    fullPallets,
    remainingLayers,
    partialPieces,
    actualM2,
    m2PerPiece,
    m2PerLayer,
    m2PerPallet: layersPerPallet * m2PerLayer,
  };
}

module.exports = { pavingCalcFromM2 };
