import asyncio
import sys
import os
from aiohttp import ClientSession
"""

Usage: Connect to absnp api to check if alleles are in forward strand. Loops through .bim ending files within root_dir. 
"""


root_dir = sys.argv[1]
dataset_name = sys.argv[2]

async def fetch_data(rsids, session):
    url = "https://clinicaltables.nlm.nih.gov/api/snps/v3/search"
    tasks = []
    for rsid in rsids:
        params = {'terms': rsid}
        task = asyncio.ensure_future(fetch(session, url, params))
        tasks.append(task)
        await asyncio.sleep(0.1) 
    return await asyncio.gather(*tasks)

async def fetch(session, url, params):
    async with session.get(url, params=params) as response:
        return await response.json()

async def query_dbsnp(rsid, position,bim_ref, write_file, session, dataset_name):
    try:
        data = await fetch_data([rsid], session)
        if data:
            for alleles in data[0][3][0]:
                if "/" in alleles:
                    ref_allele = alleles[0]
                    if ref_allele != bim_ref:
                        with open('validate/' + dataset_name + "/" + dataset_name + '.allele_mismatch.txt', 'a') as map_file:
                            map_file.write(f'{rsid} {ref_allele} {bim_ref}\n' )
                            #map_file.write(f'{data}\n' )
            dbsnp_position = data[0][3][0][2]
            if int(dbsnp_position) + 1 != int(position):
                actual = int(dbsnp_position) + 1
                write_file.write(f"{rsid} in bim file: {position}, Actual: {actual}\n")
                if int(actual) - int(position) ==1:
                    with open('validate/' + dataset_name + "/" + dataset_name+'mapping.txt', 'a') as map_file:
                        map_file.write(f'{rsid} {actual}\n' ) 
    except Exception as err:
        exception_file = dataset_name + '.exception.txt'
        with open('validate/' + dataset_name + "/" + exception_file, 'a') as ex_file:
            ex_file.write(f"{rsid} {err}\n")

async def main():
    batch_size = 20
    session = ClientSession()
    try:
        dataset_dir = os.path.join(root_dir, dataset_name)
        for dirpath, dirnames, filenames in os.walk(dataset_dir):
            print("Directory path:", dirpath)
            print("Subdirectories:", dirnames)
            print("Files:", filenames)
            for filename in filenames:
                if filename.endswith('.bim'):
                    file_path = os.path.join(dirpath, filename)
                    print(file_path)
                    chunks = file_path.split('/') 
                    with open('validate/'+ dataset_name + "/" +dataset_name+'.txt', 'w') as mismatch_file:
                        with open(file_path, 'r') as file:
                            rsids = []
                            for line in file:
                                parts = line.strip().split('\t')
                                rsid = parts[1]
                                position = parts[3]
                                bim_ref = parts[5] 
                                rsids.append((rsid, position, bim_ref))
                                if len(rsids) == batch_size:
                                    await query_dbsnp_batch(rsids, mismatch_file, session, dataset_name)
                                    rsids = []
                                    await asyncio.sleep(0.1)
                            if rsids:
                                await query_dbsnp_batch(rsids, mismatch_file, session, dataset_name)
                                await asyncio.sleep(0.1)
    finally:
        await session.close()

async def query_dbsnp_batch(rsids, write_file, session, dataset_name):
    tasks = [query_dbsnp(rsid, position, bim_ref, write_file, session, dataset_name) for rsid, position, bim_ref in rsids]
    await asyncio.gather(*tasks)

if __name__ == "__main__":
    asyncio.run(main())

