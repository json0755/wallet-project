import axios from 'axios';

// 创建axios实例，配置基础URL和请求拦截器
const api = axios.create({
  baseURL: process.env.NODE_ENV === 'development' ? '' : '/api',
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// 请求拦截器
api.interceptors.request.use(
  (config) => {
    // 在开发环境下，确保不使用系统代理
    if (process.env.NODE_ENV === 'development') {
      // 对于本地开发，使用React的代理配置
      config.proxy = false;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// 响应拦截器
api.interceptors.response.use(
  (response) => {
    return response;
  },
  (error) => {
    console.error('API请求错误:', error);
    
    // 处理网络错误
    if (error.code === 'ECONNABORTED') {
      error.message = '请求超时，请检查网络连接';
    } else if (error.code === 'ERR_NETWORK') {
      error.message = '网络连接失败，请检查后端服务是否正常运行';
    } else if (error.response) {
      // 服务器响应了错误状态码
      const { status, data } = error.response;
      switch (status) {
        case 404:
          error.message = '请求的资源不存在';
          break;
        case 500:
          error.message = '服务器内部错误';
          break;
        default:
          error.message = data?.message || `请求失败 (${status})`;
      }
    }
    
    return Promise.reject(error);
  }
);

export default api;