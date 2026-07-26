const { MongoClient } = require('mongodb');
const dns = require('dns');
const fs = require('fs');
const path = require('path');

dns.setServers(['8.8.8.8', '1.1.1.1']);

const FITCRON_FILE = 'C:\\Users\\idmr_\\.local\\share\\opencode\\tool-output\\tool_f9c22fafa001yAxU8lpEu6PFsp';

// Category mapping: FitCron -> app categories
const CATEGORY_MAP = {
  'Abdomen': 'fuerza',
  'Todos': 'fuerza',
  'Pierna': 'fuerza',
  'Espalda': 'fuerza',
  'Hombro': 'fuerza',
  'Triceps': 'fuerza',
  'Biceps': 'fuerza',
  'Pecho': 'fuerza',
  'Cuello': 'fuerza',
  'Antebrazo': 'fuerza',
  'AEROBIC': 'cardio'
};

// Muscle group -> Spanish description
function generateDescription(exercise) {
  const muscles = exercise.muscles || [];
  const equipment = exercise.equipment || 'sin equipo';
  const difficulty = exercise.difficulty === '1' ? 'principiante' : 
                     exercise.difficulty === '2' ? 'intermedio' : 'avanzado';
  
  return `${exercise.name} - ${exercise.type || 'Fuerza'}. Musculos principales: ${exercise.mainMuscle || muscles.join(', ')}. Equipo: ${equipment}. Dificultad: ${difficulty}.`;
}

// Normalize name for dedup
function normalizeName(name) {
  return (name || '').toLowerCase().trim().replace(/\s+/g, ' ');
}

async function run() {
  const client = new MongoClient(process.env.MONGODB_URI);
  await client.connect();
  
  const db = client.db();
  const exercises = db.collection('exercises');
  const routines = db.collection('routines');
  const workouts = db.collection('workouts');
  
  console.log('=== STEP 1: Delete orphan exercises (source=null, no externalId) ===');
  const orphanResult = await exercises.deleteMany({
    $or: [
      { source: null },
      { source: undefined },
      { externalId: null },
      { externalId: undefined },
      { externalId: '' }
    ]
  });
  console.log(`  Deleted ${orphanResult.deletedCount} orphan exercises`);
  
  console.log('\n=== STEP 2: Delete SVG placeholders ===');
  const svgResult = await exercises.deleteMany({
    localImageMime: 'image/svg+xml'
  });
  console.log(`  Deleted ${svgResult.deletedCount} SVG placeholders`);
  
  console.log('\n=== STEP 3: Delete exercises with no useful images ===');
  const noImageResult = await exercises.deleteMany({
    $and: [
      { gifUrl: { $in: [null, ''] } },
      { imageUrl: { $in: [null, ''] } },
      { localImage: null }
    ]
  });
  console.log(`  Deleted ${noImageResult.deletedCount} exercises with no images`);
  
  console.log('\n=== STEP 4: Clean dangling references in routines ===');
  const remainingExerciseIds = await exercises.distinct('externalId');
  const remainingExerciseSet = new Set(remainingExerciseIds);
  
  const allRoutines = await routines.find({}).toArray();
  let danglingRefsFixed = 0;
  
  for (const routine of allRoutines) {
    if (!routine.exercises || !Array.isArray(routine.exercises)) continue;
    
    const originalLength = routine.exercises.length;
    routine.exercises = routine.exercises.filter(ex => 
      ex.exercise && remainingExerciseSet.has(ex.exercise)
    );
    
    if (routine.exercises.length !== originalLength) {
      danglingRefsFixed += originalLength - routine.exercises.length;
      await routines.updateOne(
        { _id: routine._id },
        { $set: { exercises: routine.exercises } }
      );
      console.log(`  Fixed routine "${routine.name}": removed ${originalLength - routine.exercises.length} dangling refs`);
    }
  }
  console.log(`  Total dangling refs fixed: ${danglingRefsFixed}`);
  
  console.log('\n=== STEP 5: Import FitCron data ===');
  const fitcronData = JSON.parse(fs.readFileSync(FITCRON_FILE, 'utf8'));
  
  // Flatten all exercises from all categories
  const allFitcronExercises = [];
  for (const category of fitcronData) {
    for (const exercise of category.exercises) {
      allFitcronExercises.push({
        ...exercise,
        categoryName: category.category
      });
    }
  }
  
  // Dedup by name within FitCron
  const seenNames = new Set();
  const uniqueFitcronExercises = [];
  
  for (const ex of allFitcronExercises) {
    const normalizedName = normalizeName(ex.name);
    if (!seenNames.has(normalizedName)) {
      seenNames.add(normalizedName);
      uniqueFitcronExercises.push(ex);
    }
  }
  
  console.log(`  FitCron total: ${allFitcronExercises.length}, unique: ${uniqueFitcronExercises.length}`);
  
  // Check existing exercises by name
  const existingNames = new Set();
  const existingExercises = await exercises.find({}).toArray();
  for (const ex of existingExercises) {
    existingNames.add(normalizeName(ex.name));
    if (ex.nameSpanish) {
      existingNames.add(normalizeName(ex.nameSpanish));
    }
  }
  
  // Insert only new exercises
  let imported = 0;
  let skipped = 0;
  
  for (const fitcronEx of uniqueFitcronExercises) {
    const normalizedName = normalizeName(fitcronEx.name);
    
    if (existingNames.has(normalizedName)) {
      skipped++;
      continue;
    }
    
    // Extract ID from link: /exercise/curl-concentrado-en-supinacion-con-barra-antebrazo/
    const linkSlug = fitcronEx.link.replace('/exercise/', '').replace(/\/$/, '');
    const externalId = `fitcron_${linkSlug}`;
    
    const exerciseDoc = {
      externalId: externalId,
      name: fitcronEx.name,
      nameSpanish: fitcronEx.name,
      description: generateDescription(fitcronEx),
      descriptionSpanish: generateDescription(fitcronEx),
      category: CATEGORY_MAP[fitcronEx.categoryName] || 'fuerza',
      source: 'fitcron',
      imageUrl: fitcronEx.image,
      gifUrl: fitcronEx.image,
      difficulty: parseInt(fitcronEx.difficulty) || 2,
      equipment: fitcronEx.equipment,
      muscles: fitcronEx.muscles || [fitcronEx.mainMuscle],
      mainMuscle: fitcronEx.mainMuscle,
      type: fitcronEx.type || 'Fuerza',
      createdAt: new Date()
    };
    
    try {
      await exercises.insertOne(exerciseDoc);
      imported++;
    } catch (e) {
      console.error(`  Error importing "${fitcronEx.name}": ${e.message}`);
    }
  }
  
  console.log(`  Imported: ${imported}, Skipped (duplicates): ${skipped}`);
  
  console.log('\n=== STEP 6: Enrich exercisedb exercises with Spanish names ===');
  const fitcronByName = {};
  for (const ex of uniqueFitcronExercises) {
    fitcronByName[normalizeName(ex.name)] = ex;
  }
  
  const exercisedbExercises = await exercises.find({ source: 'exercisedb' }).toArray();
  let enriched = 0;
  
  for (const ex of exercisedbExercises) {
    // Try to find matching FitCron exercise
    const normalizedName = normalizeName(ex.name);
    const fitcronMatch = fitcronByName[normalizedName];
    
    if (fitcronMatch && !ex.nameSpanish) {
      await exercises.updateOne(
        { _id: ex._id },
        { $set: { nameSpanish: fitcronMatch.name } }
      );
      enriched++;
    }
  }
  
  console.log(`  Enriched ${enriched} exercisedb exercises with Spanish names`);
  
  // Final stats
  console.log('\n=== FINAL STATS ===');
  const total = await exercises.countDocuments({});
  const withSvg = await exercises.countDocuments({ localImageMime: 'image/svg+xml' });
  const withoutSpanish = await exercises.countDocuments({
    $and: [
      { nameSpanish: { $in: [null, ''] } },
      { descriptionSpanish: { $in: [null, ''] } }
    ]
  });
  const bySource = await exercises.aggregate([
    { $group: { _id: '$source', count: { $sum: 1 } } }
  ]).toArray();
  
  console.log(`  Total exercises: ${total}`);
  console.log(`  SVG placeholders: ${withSvg}`);
  console.log(`  Without Spanish desc/name: ${withoutSpanish}`);
  console.log(`  By source:`, bySource.map(s => `${s._id || 'null'}: ${s.count}`).join(', '));
  
  await client.close();
  console.log('\n✓ Done!');
}

require('dotenv').config();
run().catch(console.error);
