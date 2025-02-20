from rdkit import Chem
from rdkit.Chem import DataStructs
from rdkit.Chem import rdMolDescriptors
from rdkit.Chem import Descriptors
from rdkit.Chem import rdqueries
import json

def rdkit_draw_png(request):
    from rdkit.Chem.Draw import rdMolDraw2D
    import base64
    try:
        return_value = []
        request_json = request.get_json()
        calls = request_json['calls']
        
        for call in calls:       
            smiles = call[0]            
            try:
                mc = Chem.MolFromSmiles(smiles)
                drawer = rdMolDraw2D.MolDraw2DCairo(*(450,150))
                drawer.DrawMolecule(mc)
                drawer.FinishDrawing()
                png = drawer.GetDrawingText()
                png = base64.b64encode(png).decode('utf-8')
                return_value.append(png)
            except:
                return_value.append("")

        return_json = json.dumps( { "replies" :  return_value} ), 200
        return return_json
    except Exception:
        return json.dumps( { "errorMessage": 'something unexpected in input' } ), 400