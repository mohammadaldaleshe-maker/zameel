import assert from 'node:assert/strict';
import {readFile,mkdtemp,writeFile,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
const data=JSON.parse(await readFile('docs/academic_catalog_150.json','utf8'));
assert.equal(data.raw_record_count,2342);assert.equal(new Set(data.programs.map(x=>x.sequence)).size,2342);
const model=(await readFile('lib/features/university.dart','utf8')).split('// UNIVERSITY SCREEN')[0].replace(/^part .*;\r?\n/, '');
const catalog=(await readFile('lib/features/academic_catalog_150.dart','utf8')).replace(/^part .*;\r?\n/,'');
const temp=await mkdtemp(path.join(tmpdir(),'zameel-academic-'));
try {
 const file=path.join(temp,'catalog.dart');
 await writeFile(file,`import 'dart:convert';\n${model}\n${catalog}\nvoid main(){
 for(final u in legacyUniversities){final merged=universities.singleWhere((x)=>x.name==u.name);for(final c in u.colleges){final mc=merged.colleges.singleWhere((x)=>x.name==c.name);if(!c.departments.every(mc.departments.contains))throw StateError('lost legacy major');}}
 if(universities.map((u)=>u.name).toSet().length!=universities.length)throw StateError('duplicate institution');
 print(jsonEncode([for(final u in officialJordanUniversities150) {'name':u.name,'colleges':[for(final c in u.colleges){'name':c.name,'programs':c.programDegrees}]}]));}
`);
 const result=spawnSync(process.env.ZAMEEL_DART||'dart',[file],{encoding:'utf8',maxBuffer:10*1024*1024});
 assert.equal(result.status,0,result.stderr);const compiled=JSON.parse(result.stdout);
 assert(compiled.length>=63);
 for(const row of [...data.programs,...data.supplemental_programs]){assert(compiled.some(u=>u.name===data.institution_mapping[row.institution]&&u.colleges.some(c=>c.name===row.faculty&&c.programs[row.major]?.includes(row.degree))),`lost official program ${row.sequence}`);}
 console.log('PASS: compiled academic data, all 2342 source records retained, legacy identity/majors preserved, unique institution names.');
}finally{await rm(temp,{recursive:true,force:true});}
