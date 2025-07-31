const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const fs = require('fs');

// 数据库文件路径
const DB_PATH = path.join(__dirname, '../data/transactions.db');

let db = null;

/**
 * 初始化数据库连接和表结构
 */
async function initDatabase() {
  return new Promise((resolve, reject) => {
    try {
      // 确保数据目录存在
      const dataDir = path.dirname(DB_PATH);
      if (!fs.existsSync(dataDir)) {
        fs.mkdirSync(dataDir, { recursive: true });
      }

      // 创建数据库连接
      db = new sqlite3.Database(DB_PATH, (err) => {
        if (err) {
          console.error('❌ 数据库连接失败:', err.message);
          reject(err);
          return;
        }
        console.log('✅ 已连接到SQLite数据库:', DB_PATH);
      });

      // 创建表结构
      const createTableSQL = `
        CREATE TABLE IF NOT EXISTS transfers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          tx_hash TEXT UNIQUE NOT NULL,
          from_address TEXT NOT NULL,
          to_address TEXT NOT NULL,
          amount TEXT NOT NULL,
          timestamp INTEGER NOT NULL,
          block_number INTEGER NOT NULL,
          token_address TEXT NOT NULL,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
      `;

      db.run(createTableSQL, (err) => {
        if (err) {
          console.error('❌ 创建表失败:', err.message);
          reject(err);
          return;
        }
        console.log('✅ transfers表创建/验证完成');
      });

      // 创建索引以优化查询性能
      const createIndexes = [
        'CREATE INDEX IF NOT EXISTS idx_from_address ON transfers(from_address)',
        'CREATE INDEX IF NOT EXISTS idx_to_address ON transfers(to_address)',
        'CREATE INDEX IF NOT EXISTS idx_block_number ON transfers(block_number)',
        'CREATE INDEX IF NOT EXISTS idx_timestamp ON transfers(timestamp)',
        'CREATE INDEX IF NOT EXISTS idx_token_address ON transfers(token_address)'
      ];

      let indexCount = 0;
      createIndexes.forEach((indexSQL) => {
        db.run(indexSQL, (err) => {
          if (err) {
            console.error('❌ 创建索引失败:', err.message);
          }
          indexCount++;
          if (indexCount === createIndexes.length) {
            console.log('✅ 数据库索引创建完成');
            resolve();
          }
        });
      });
    } catch (error) {
      reject(error);
    }
  });
}

/**
 * 获取数据库连接
 */
function getDatabase() {
  if (!db) {
    throw new Error('数据库未初始化，请先调用 initDatabase()');
  }
  return db;
}

/**
 * 批量插入转账记录
 * @param {Array} transfers - 转账记录数组
 */
async function insertTransfers(transfers) {
  return new Promise((resolve, reject) => {
    if (!transfers || transfers.length === 0) {
      resolve({ inserted: 0, skipped: 0 });
      return;
    }

    const db = getDatabase();
    const insertSQL = `
      INSERT OR IGNORE INTO transfers 
      (tx_hash, from_address, to_address, amount, timestamp, block_number, token_address)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `;

    db.serialize(() => {
      const stmt = db.prepare(insertSQL);
      let inserted = 0;
      let processed = 0;

      transfers.forEach((transfer) => {
        stmt.run([
          transfer.txHash,
          transfer.from,
          transfer.to,
          transfer.amount,
          transfer.timestamp,
          transfer.blockNumber,
          transfer.tokenAddress
        ], function(err) {
          if (err) {
            console.error('❌ 插入转账记录失败:', err.message);
          } else if (this.changes > 0) {
            inserted++;
          }
          
          processed++;
          if (processed === transfers.length) {
            stmt.finalize();
            const skipped = transfers.length - inserted;
            console.log(`📊 批量插入完成: ${inserted} 条新记录, ${skipped} 条重复跳过`);
            resolve({ inserted, skipped });
          }
        });
      });
    });
  });
}

/**
 * 查询地址相关的转账记录
 * @param {string} address - 钱包地址
 * @param {number} page - 页码
 * @param {number} limit - 每页数量
 */
async function getTransactionsByAddress(address, page = 1, limit = 50) {
  return new Promise((resolve, reject) => {
    const db = getDatabase();
    const offset = (page - 1) * limit;
    
    const querySQL = `
      SELECT 
        tx_hash as txHash,
        from_address as fromAddress,
        to_address as toAddress,
        amount,
        timestamp,
        block_number as blockNumber,
        token_address as tokenAddress
      FROM transfers 
      WHERE from_address = ? OR to_address = ?
      ORDER BY timestamp DESC, block_number DESC
      LIMIT ? OFFSET ?
    `;

    const countSQL = `
      SELECT COUNT(*) as total
      FROM transfers 
      WHERE from_address = ? OR to_address = ?
    `;

    // 先获取总数
    db.get(countSQL, [address, address], (err, countResult) => {
      if (err) {
        reject(err);
        return;
      }

      const total = countResult.total;
      
      // 再获取分页数据
      db.all(querySQL, [address, address, limit, offset], (err, rows) => {
        if (err) {
          reject(err);
          return;
        }

        resolve({
          transactions: rows,
          pagination: {
            page,
            limit,
            total,
            totalPages: Math.ceil(total / limit)
          }
        });
      });
    });
  });
}

/**
 * 获取最新的区块号
 */
async function getLatestBlockNumber() {
  return new Promise((resolve, reject) => {
    const db = getDatabase();
    const querySQL = 'SELECT MAX(block_number) as latestBlock FROM transfers';
    
    db.get(querySQL, (err, row) => {
      if (err) {
        reject(err);
        return;
      }
      resolve(row.latestBlock || 0);
    });
  });
}

/**
 * 关闭数据库连接
 */
function closeDatabase() {
  if (db) {
    db.close((err) => {
      if (err) {
        console.error('❌ 关闭数据库失败:', err.message);
      } else {
        console.log('✅ 数据库连接已关闭');
      }
    });
  }
}

module.exports = {
  initDatabase,
  getDatabase,
  insertTransfers,
  getTransactionsByAddress,
  getLatestBlockNumber,
  closeDatabase
};